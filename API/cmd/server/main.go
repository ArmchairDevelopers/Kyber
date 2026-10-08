package main

import (
	"context"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"time"

	"github.com/ArmchairDevelopers/Kyber/API/api/v1/pbapi"
	"github.com/ArmchairDevelopers/Kyber/API/internal/api"
	"github.com/ArmchairDevelopers/Kyber/API/internal/cache"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/db"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/featureflags"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/jwts"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/logger"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/mq"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/queue"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/safego"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/ws"
	"github.com/getsentry/sentry-go"
	sentryhttp "github.com/getsentry/sentry-go/http"
	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"

	"github.com/ArmchairDevelopers/Kyber/API/internal/rpc"
	"github.com/gorilla/mux"
	"github.com/grpc-ecosystem/go-grpc-middleware/v2/interceptors/logging"
	"go.uber.org/zap"
	"go.uber.org/zap/zapgrpc"
	"golang.org/x/sync/errgroup"
	"google.golang.org/grpc"
	"google.golang.org/grpc/grpclog"
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
	err := sentry.Init(sentry.ClientOptions{
		Dsn:              sentryDSN,
		Environment:      os.Getenv("ENVIRONMENT"),
		SendDefaultPII:   true,
		TracesSampleRate: 0.2,
	})
	if err != nil {
		log.Fatalf("sentry.Init: %s", err)
	}
	defer sentry.Flush(2 * time.Second)

	if err := logger.Init(sentry.CurrentHub().Client()); err != nil {
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

	mqClient, err := mq.NewClient(amqpURL, []mq.ExchangeConfig{
		{Name: "player_events", Kind: "topic", Durable: true},
		{Name: "image_hashes", Kind: "fanout", Durable: true},
		{Name: "reports", Kind: "fanout", Durable: true},
		{Name: "kronos_server_browser", Kind: "fanout", Durable: true},
		{Name: "session_events", Kind: "fanout", Durable: true},
	})
	if err != nil {
		panic("failed to connect to RabbitMQ: " + err.Error())
	}
	defer mqClient.Close()

	partyPub := mq.NewPartyEventPublisher(mqClient)
	queuePub := mq.NewQueueEventPublisher(mqClient)

	caches := cache.New(redisClient)

	dockerAuth := api.NewDockerAuthState(store)
	discordAuth := api.NewDiscordAuthState(store, caches)

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
	featureFlags := featureflags.New(os.Getenv("LIGHTSWITCH_URL"), os.Getenv("ENVIRONMENT"))
	queueManager := queue.NewManager(store, queuePub, featureFlags)
	sessionManager := ws.NewSessionManager(store, partyPub, queueManager)
	serverManager := ws.NewServerManager(ctx, amqpURL, store, caches)
	serverManager.OnPlayerCountUpdated = func(serverID string) {
		go queueManager.Advance(context.Background(), serverID)
	}

	safego.Go(func() { sessionManager.ConsumeSessionEvents(mqClient) })

	httpHandler := sentryHandler.Handle(httpRouter)

	httpRouter.HandleFunc("/.well-known/jwks.json", api.JWKSHandler(jwtService)).Methods(http.MethodGet)
	httpRouter.HandleFunc("/docker/auth", dockerAuth.AuthHandler).Methods(http.MethodGet)
	httpRouter.HandleFunc("/discord/auth", discordAuth.AuthHandler).Methods(http.MethodGet)
	httpRouter.HandleFunc("/discord/callback", discordAuth.CallbackHandler).Methods(http.MethodGet)
	httpRouter.HandleFunc("/download/{obj}", downloadManager.DownloadHandler).Methods(http.MethodGet)
	httpRouter.HandleFunc("/images/{id}.jpeg", imageManager.ImageHandler).Methods(http.MethodGet)
	httpRouter.HandleFunc("/health", api.HealthHandler).Methods(http.MethodGet)
	httpRouter.HandleFunc("/redirect", api.RedirectHandler).Methods(http.MethodGet)

	httpRouter.HandleFunc("/ws/server/{id}", wrapWS(serverManager.HandleServerWS)).Methods(http.MethodGet)
	httpRouter.HandleFunc("/ws/client/{id}", wrapWS(serverManager.HandleClientWS)).Methods(http.MethodGet)
	httpRouter.HandleFunc("/ws/session", wrapWS(sessionManager.HandleWS)).Methods(http.MethodGet)

	lis, err := net.Listen("tcp", fmt.Sprintf(":%s", grpcPort))
	if err != nil {
		logger.L().Panic("failed to listen", zap.Error(err))
	}

	zapLogger := logger.L()
	grpclog.SetLoggerV2(zapgrpc.NewLogger(zapLogger))

	sentryOpts := rpc.DefaultSentryOptions()
	grpcLogger := zapInterceptorLogger(logger.Console())

	grpcServer := grpc.NewServer(
		grpc.ChainUnaryInterceptor(
			rpc.SentryUnaryServerInterceptor(sentryOpts),
			logging.UnaryServerInterceptor(grpcLogger, logging.WithLogOnEvents(logging.FinishCall)),
			rpc.NewFeatureInterceptor(featureFlags),
			rpc.NewAuthHandler(store).NewAuthInterceptor(),
		),
		grpc.ChainStreamInterceptor(
			rpc.SentryStreamServerInterceptor(sentryOpts),
			logging.StreamServerInterceptor(grpcLogger, logging.WithLogOnEvents(logging.FinishCall)),
			rpc.NewAuthHandler(store).NewAuthStreamInterceptor(),
		),
	)

	reflection.Register(grpcServer)
	pbapi.RegisterAuthenticationServer(grpcServer, rpc.NewAuthenticationServer(ctx, store, mqClient))
	pbapi.RegisterServerBrowserServer(grpcServer, rpc.NewServerBrowserServer(store, serverManager, mqClient, jwtService, sessionManager, partyPub, queueManager, caches))
	pbapi.RegisterClientServerServer(grpcServer, rpc.NewClientServer(store, jwtService, queueManager))
	pbapi.RegisterLauncherServer(grpcServer, rpc.NewLauncherServer(store, minioClient, caches))
	pbapi.RegisterServerManagementServer(grpcServer, rpc.NewServerManagementServer(store, serverManager))
	pbapi.RegisterStatisticsServer(grpcServer, rpc.NewStatisticsServer(ctx, store, caches))
	pbapi.RegisterVoipServer(grpcServer, rpc.NewVoipServer(store))
	pbapi.RegisterProxyServer(grpcServer, rpc.NewProxyServer())
	pbapi.RegisterReportServiceServer(grpcServer, rpc.NewReportServer(store, serverManager, mqClient))
	pbapi.RegisterPartyServer(grpcServer, rpc.NewPartyServer(store, partyPub, sessionManager, queueManager))
	pbapi.RegisterServerQueueServer(grpcServer, rpc.NewQueueServer(store, queueManager))

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

func zapInterceptorLogger(l *zap.Logger) logging.Logger {
	return logging.LoggerFunc(func(ctx context.Context, lvl logging.Level, msg string, fields ...any) {
		f := make([]zap.Field, 0, len(fields)/2)
		it := logging.Fields(fields).Iterator()

		for it.Next() {
			k, v := it.At()
			f = append(f, zap.Any(k, v))
		}

		lg := l.WithOptions(zap.AddCallerSkip(1)).With(f...)

		switch lvl {
		case logging.LevelDebug:
			lg.Debug(msg)
		case logging.LevelInfo:
			lg.Info(msg)
		case logging.LevelWarn:
			lg.Warn(msg)
		case logging.LevelError:
			lg.Error(msg)
		default:
			lg.Info(msg)
		}
	})
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
