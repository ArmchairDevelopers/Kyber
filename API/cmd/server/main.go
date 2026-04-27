package main

import (
	"context"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/ArmchairDevelopers/Kyber/API/api/v1/pbapi"
	"github.com/ArmchairDevelopers/Kyber/API/internal/api"
	"github.com/ArmchairDevelopers/Kyber/API/internal/cache"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/db"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/jwts"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/logger"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/mq"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/ws"
	"github.com/getsentry/sentry-go"
	sentryhttp "github.com/getsentry/sentry-go/http"
	grpc_recovery "github.com/grpc-ecosystem/go-grpc-middleware/recovery"
	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"

	"github.com/ArmchairDevelopers/Kyber/API/internal/rpc"
	"github.com/gorilla/mux"
	grpc_middleware "github.com/grpc-ecosystem/go-grpc-middleware"
	grpc_zap "github.com/grpc-ecosystem/go-grpc-middleware/logging/zap"
	grpc_ctxtags "github.com/grpc-ecosystem/go-grpc-middleware/tags"
	"github.com/grpc-ecosystem/grpc-gateway/v2/runtime"
	grpc_sentry "github.com/johnbellone/grpc-middleware-sentry"
	"github.com/rs/cors"
	"go.uber.org/zap"
	"golang.org/x/sync/errgroup"
	"google.golang.org/grpc"
	"google.golang.org/grpc/reflection"
)

func main() {
	grpcPort := os.Getenv("GRPC_PORT")
	httpPort := os.Getenv("HTTP_PORT")
	mongoURI := os.Getenv("MONGO_URI")
	amqpURL := os.Getenv("AMQP_URL")

	if grpcPort == "" {
		grpcPort = "9027"
	}

	if httpPort == "" {
		httpPort = "9028"
	}

	sentryDSN := os.Getenv("SENTRY_DSN")
	err := sentry.Init(sentry.ClientOptions{Dsn: sentryDSN, SendDefaultPII: true, TracesSampleRate: 1.0})
	if err != nil {
		log.Fatalf("sentry.Init: %s", err)
	}
	defer sentry.Flush(2 * time.Second)

	client, err := sentry.NewClient(sentry.ClientOptions{Dsn: sentryDSN})
	if err := logger.Init(client); err != nil {
		log.Fatalf("logger.Init: %v", err)
	}
	defer logger.Sync()

	logger.L().Info("Starting Kyber API")

	ctx := context.Background()

	store, err := db.NewStore(ctx, mongoURI)
	if err != nil {
		logger.L().Error("db.NewStore failed", zap.Error(err))
	}

	defer func() {
		cctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if err := db.Close(cctx); err != nil {
			logger.L().Error("db.Close failed", zap.Error(err))
		}
	}()

	minioEndpoint := os.Getenv("MINIO_HOST")
	accessKey := os.Getenv("MINIO_ACCESS_KEY")
	secretKey := os.Getenv("MINIO_SECRET_KEY")

	if minioEndpoint == "" || accessKey == "" || secretKey == "" {
		panic("MINIO_HOST, MINIO_ACCESS_KEY, and MINIO_SECRET_KEY must be set")
	}

	minioClient, err := minio.New(minioEndpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(accessKey, secretKey, ""),
		Secure: true,
	})

	if err != nil {
		panic("Failed to create MinIO client: " + err.Error())
	}

	redisURL := os.Getenv("REDIS_URI")
	if redisURL == "" {
		panic("REDIS_URI environment variable is not set")
	}

	redisClient, err := cache.NewRedisClient(redisURL)
	if err != nil {
		panic("Failed to create Redis client: " + err.Error())
	}
	defer redisClient.Close()

	statsCache := cache.NewStatsCache(redisClient, 10*time.Minute)
	patronsCache := cache.NewPatronsCache(redisClient, time.Hour)
	discordCache := cache.NewDiscordAuthCache(redisClient, 5*time.Minute)

	sm := ws.NewServerManager(ctx, amqpURL, store)
	dockerAuth := api.NewDockerAuthState(store)
	discordAuth := api.NewDiscordAuthState(store, discordCache)

	jwtService, err := jwts.NewService()
	if err != nil {
		logger.L().Fatal("failed to initialize JWT service", zap.Error(err))
	}

	httpRouter := mux.NewRouter()
	sentryHandler := sentryhttp.New(sentryhttp.Options{
		Repanic:         true,
		WaitForDelivery: true,
		Timeout:         2 * time.Second,
	})

	downloadManager := api.NewDownloadManager(minioClient)
	imageManager := api.NewImageManager(store)

	allowedOrigins := strings.Split(os.Getenv("CORS_ORIGINS"), ",")

	for i, o := range allowedOrigins {
		allowedOrigins[i] = strings.TrimSpace(o)
	}

	corsMW := cors.New(cors.Options{
		AllowedOrigins:   allowedOrigins,
		AllowedMethods:   []string{http.MethodGet, http.MethodPost, http.MethodPut, http.MethodPatch, http.MethodDelete, http.MethodOptions},
		AllowedHeaders:   []string{"Authorization", "Content-Type", "X-Grpc-Web", "Grpc-Timeout", "X-User-Agent"},
		ExposedHeaders:   []string{"Grpc-Status", "Grpc-Message", "Grpc-Status-Details-Bin"},
		AllowCredentials: true,
		MaxAge:           600,
	})

	httpHandler := corsMW.Handler(sentryHandler.Handle(httpRouter))

	httpRouter.HandleFunc("/docker/auth", dockerAuth.AuthHandler).Methods(http.MethodGet)
	httpRouter.HandleFunc("/discord/auth", discordAuth.AuthHandler).Methods(http.MethodGet)
	httpRouter.HandleFunc("/discord/callback", discordAuth.CallbackHandler).Methods(http.MethodGet)
	httpRouter.HandleFunc("/.well-known/jwks.json", api.JWKSHandler(jwtService)).Methods(http.MethodGet)
	httpRouter.HandleFunc("/ws/server/{id}", wrapWS(sm.HandleServerWS)).Methods(http.MethodGet)
	httpRouter.HandleFunc("/ws/client/{id}", wrapWS(sm.HandleClientWS)).Methods(http.MethodGet)
	httpRouter.HandleFunc("/download/{obj}", downloadManager.DownloadHandler).Methods(http.MethodGet)
	httpRouter.HandleFunc("/images/{id}.jpeg", imageManager.ImageHandler).Methods(http.MethodGet)
	httpRouter.HandleFunc("/health", api.HealthHandler).Methods(http.MethodGet)
	httpRouter.HandleFunc("/redirect", api.RedirectHandler).Methods(http.MethodGet)

	lis, err := net.Listen("tcp", fmt.Sprintf(":%s", grpcPort))
	if err != nil {
		logger.L().Panic("failed to listen", zap.Error(err))
	}

	zapLogger := logger.L()
	grpc_zap.ReplaceGrpcLoggerV2(zapLogger)

	grpcServer := grpc.NewServer(
		grpc.UnaryInterceptor(grpc_middleware.ChainUnaryServer(
			grpc_sentry.UnaryServerInterceptor(),
			grpc_ctxtags.UnaryServerInterceptor(
				grpc_ctxtags.WithFieldExtractor(grpc_ctxtags.CodeGenRequestFieldExtractor),
			),
			grpc_zap.UnaryServerInterceptor(zapLogger),
			grpc_recovery.UnaryServerInterceptor(),
			rpc.NewAuthHandler(store).NewAuthInterceptor(),
		)),
		grpc.StreamInterceptor(grpc_middleware.ChainStreamServer(
			grpc_sentry.StreamServerInterceptor(),
			grpc_ctxtags.StreamServerInterceptor(
				grpc_ctxtags.WithFieldExtractor(grpc_ctxtags.CodeGenRequestFieldExtractor),
			),
			grpc_zap.StreamServerInterceptor(zapLogger),
			grpc_recovery.StreamServerInterceptor(),
		)),
	)

	mqClient, err := mq.NewClient(amqpURL)
	if err != nil {
		log.Fatalf("failed to connect to RabbitMQ: %v", err)
	}
	defer mqClient.Close()

	exchanges := []mq.ExchangeConfig{
		{Name: "player_events", Kind: "topic", Durable: true},
		{Name: "image_hashes", Kind: "fanout", Durable: true},
		{Name: "reports", Kind: "fanout", Durable: true},
		{Name: "kronos_server_browser", Kind: "fanout", Durable: true},
	}

	for _, cfg := range exchanges {
		if err := mqClient.DeclareExchange(cfg); err != nil {
			log.Fatalf("could not declare %s: %v", cfg.Name, err)
		}
	}

	reflection.Register(grpcServer)

	authServer := rpc.NewAuthenticationServer(ctx, store, *mqClient)
	serverBrowser := rpc.NewServerBrowserServer(store, sm, *mqClient, jwtService)
	clientServer := rpc.NewClientServer(store, jwtService)
	launcherServer := rpc.NewLauncherServer(store, minioClient, patronsCache)
	serverManagement := rpc.NewServerManagementServer(store, sm)
	statisticsServer := rpc.NewStatisticsServer(ctx, store, statsCache)
	voipServer := rpc.NewVoipServer(store)
	proxyServer := rpc.NewProxyServer()
	reportServer := rpc.NewReportServer(store, sm, *mqClient)

	pbapi.RegisterAuthenticationServer(grpcServer, authServer)
	pbapi.RegisterServerBrowserServer(grpcServer, serverBrowser)
	pbapi.RegisterClientServerServer(grpcServer, clientServer)
	pbapi.RegisterLauncherServer(grpcServer, launcherServer)
	pbapi.RegisterServerManagementServer(grpcServer, serverManagement)
	pbapi.RegisterStatisticsServer(grpcServer, statisticsServer)
	pbapi.RegisterVoipServer(grpcServer, voipServer)
	pbapi.RegisterProxyServer(grpcServer, proxyServer)
	pbapi.RegisterReportServiceServer(grpcServer, reportServer)

	gwMux := runtime.NewServeMux()
	pbapi.RegisterServerBrowserHandlerServer(ctx, gwMux, serverBrowser)

	httpRouter.PathPrefix("/kyber_api.").Handler(gwMux)

	eg, _ := errgroup.WithContext(ctx)

	eg.Go(func() error {
		addr := fmt.Sprintf(":%s", httpPort)
		logger.L().Info("HTTP server listening", zap.String("addr", addr))
		srv := &http.Server{
			Addr:    addr,
			Handler: httpHandler,
		}
		go func() {
			<-ctx.Done()
			srv.Shutdown(context.Background())
		}()
		return srv.ListenAndServe()
	})

	eg.Go(func() error {
		logger.L().Info("gRPC server listening", zap.String("addr", lis.Addr().String()))
		return grpcServer.Serve(lis)
	})

	if err := eg.Wait(); err != nil {
		logger.L().Panic("failed to serve", zap.Error(err))
	}
}

func wrapWS(wsHandler func(http.ResponseWriter, *http.Request)) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		hub := sentry.CurrentHub().Clone()
		r = r.WithContext(sentry.SetHubOnContext(r.Context(), hub))

		defer func() {
			if rec := recover(); rec != nil {
				hub.Recover(rec)
				hub.Flush(2 * time.Second)
				http.Error(w, "Internal Server Error", http.StatusInternalServerError)
			}
		}()

		wsHandler(w, r)
	}
}
