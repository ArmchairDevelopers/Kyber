package rpc

import (
	"bytes"
	"context"
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"net/url"
	"os"
	"slices"
	"time"

	"github.com/ArmchairDevelopers/Kyber/API/api/v1/pbapi"
	"github.com/ArmchairDevelopers/Kyber/API/api/v1/pbcommon"
	"github.com/ArmchairDevelopers/Kyber/API/internal/cache"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/db"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/logger"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/models"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/util"
	"github.com/minio/minio-go/v7"
	amqp "github.com/rabbitmq/amqp091-go"
	"go.uber.org/zap"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
)

type LauncherConfig struct {
	DefaultChannels   map[string]string `yaml:"defaultChannels"`
	LauncherIcon      *string           `yaml:"featuredIcon"`
	PreloadedMods     []PreloadedMod    `yaml:"preloadedMods"`
	FeaturedMods      []FeaturedMod     `yaml:"featuredMods"`
	Posts             []Post            `yaml:"posts"`
	ModStorage        []ModStorage      `yaml:"modStorage"`
	DefaultModStorage string            `yaml:"defaultModStorage"`
}

type ModStorage struct {
	ID     string `yaml:"id"`
	Bucket string `yaml:"bucket"`
	Host   string `yaml:"host"`
	// Cloudflare continent codes: https://developers.cloudflare.com/ruleset-engine/rules-language/fields/reference/ip.src.continent/
	Region   string `yaml:"region"`
	IsPublic bool   `yaml:"isPublic"`
	IsMinio  bool   `yaml:"isMinio"`
}

type PreloadedMod struct {
	Name    string `yaml:"name"`
	Version string `yaml:"version"`
	URL     string `yaml:"downloadUrl"`
	Hash    string `yaml:"hash"`
}

type FeaturedMod struct {
	ModID   uint32 `yaml:"modId"`
	FileID  uint64 `yaml:"fileId"`
	ModInfo string `yaml:"modInfo"`
}

type Post struct {
	Header   string `yaml:"header"`
	Body     string `yaml:"body"`
	Link     string `yaml:"link"`
	ImageURL string `yaml:"imageUrl"`
	IconURL  string `yaml:"iconUrl"`
}

type WhitelistedChannels struct {
	Channels         map[string][]string `yaml:"whitelistedChannels"`
	AllowAllChannels bool                `default:"false" yaml:"allowAllChannels"`
}

type LauncherServer struct {
	store          *db.Store
	minio          *minio.Client
	launcherConfig *LauncherConfig
	patronsCache   *cache.PatronsCache
	amqpCh         *amqp.Channel
	wc             *WhitelistedChannels
	pbapi.UnimplementedLauncherServer
}

func NewLauncherServer(store *db.Store, minio *minio.Client, patronsCache *cache.PatronsCache) *LauncherServer {
	launcherConfig := &LauncherConfig{}
	err := util.LoadConfig("launcher-config.yaml", launcherConfig)
	if err != nil {
		panic("Failed to load launcher config file: " + err.Error())
	}

	amqpURL := os.Getenv("MOD_BRIDGE_AMQP_URL")
	var amqpCh *amqp.Channel
	if amqpURL != "" {
		logger.L().Debug("Using AMQP connection", zap.String("amqpUrl", amqpURL))
		conn, err := amqp.Dial(amqpURL)
		if err != nil {
			panic(fmt.Sprintf("Failed to connect to RabbitMQ: %v", err))
		}

		amqpCh, err := conn.Channel()
		if err != nil {
			panic(fmt.Sprintf("Failed to open a channel: %v", err))
		}

		exchange := "direct_exchange"
		if err := amqpCh.ExchangeDeclare(exchange, "direct", true, false, false, false, nil); err != nil {
			panic(fmt.Sprintf("Failed to declare exchange: %v", err))
		}
	}

	wc := &WhitelistedChannels{}
	err = util.LoadConfig("downloads.yaml", wc)
	if err != nil {
		panic("Failed to load downloads config file: " + err.Error())
	}

	for _, storage := range launcherConfig.ModStorage {
		logger.L().Debug("Mod storage config", zap.String("id", storage.ID), zap.String("bucket", storage.Bucket), zap.String("host", storage.Host), zap.Bool("isPublic", storage.IsPublic), zap.Bool("isMinio", storage.IsMinio))
	}

	return &LauncherServer{
		store:          store,
		minio:          minio,
		patronsCache:   patronsCache,
		launcherConfig: launcherConfig,
		amqpCh:         amqpCh,
		wc:             wc,
	}
}

func (s *LauncherServer) GetPreloadedMods(context.Context, *pbcommon.Empty) (*pbapi.PreloadedModsResponse, error) {
	mods := make([]*pbapi.PreloadedMod, 0)
	for _, mod := range s.launcherConfig.PreloadedMods {
		mods = append(mods, &pbapi.PreloadedMod{
			Name:    mod.Name,
			Version: mod.Version,
			Url:     mod.URL,
			Hash:    mod.Hash,
		})
	}

	return &pbapi.PreloadedModsResponse{
		Mods: mods,
	}, nil
}

func (s *LauncherServer) GetLauncherConfig(context.Context, *pbcommon.Empty) (*pbapi.LauncherConfigResponse, error) {
	mods := make([]*pbapi.FeaturedMod, 0)
	for _, mod := range s.launcherConfig.FeaturedMods {
		mods = append(mods, &pbapi.FeaturedMod{
			ModId:   mod.ModID,
			FileId:  mod.FileID,
			ModInfo: mod.ModInfo,
		})
	}

	posts := make([]*pbapi.Post, 0)
	for _, post := range s.launcherConfig.Posts {
		posts = append(posts, &pbapi.Post{
			Header:   post.Header,
			Body:     post.Body,
			Link:     post.Link,
			ImageUrl: post.ImageURL,
			IconUrl:  post.IconURL,
		})
	}

	return &pbapi.LauncherConfigResponse{
		DefaultChannels: s.launcherConfig.DefaultChannels,
		LauncherIcon:    s.launcherConfig.LauncherIcon,
		FeaturedMods:    mods,
		Posts:           posts,
	}, nil
}

func (s *LauncherServer) QueryHostedMods(ctx context.Context, req *pbapi.QueryHostedModsRequest) (*pbapi.HostedModsResponse, error) {
	var mods []*pbapi.HostedModResponseItem

	if req.GetMods() == nil {
		return nil, status.Error(codes.InvalidArgument, "No mods provided")
	}

	if len(req.GetMods()) >= 51 {
		return nil, status.Error(codes.InvalidArgument, "Too many mods provided")
	}

	meta, exist := metadata.FromIncomingContext(ctx)
	if !exist {
		return nil, status.Error(codes.Internal, "Failed to get metadata from context")
	}

	var region *string
	if req.ClientRegion != nil && *req.ClientRegion != "" {
		region = req.ClientRegion
	} else if meta.Get("cf-ipcontinent") != nil && len(meta.Get("cf-ipcontinent")) > 0 {
		region = &meta.Get("cf-ipcontinent")[0]
	}

	logger.L().Debug("QueryHostedModsRequest", zap.Any("req", req), zap.String("region", *region))

	for _, mod := range req.GetMods() {
		if mod == nil {
			return nil, status.Error(codes.InvalidArgument, "Invalid mod provided")
		}

		modItem, err := s.fetchMod(ctx, mod, region)
		if err != nil {
			if errors.Is(err, status.Error(codes.NotFound, "Mod not found")) {
				continue
			}

			logger.L().Error(err.Error())
			return nil, status.Error(codes.Internal, "Failed to fetch mod")
		}

		mods = append(mods, modItem)
	}

	return &pbapi.HostedModsResponse{
		Mods: mods,
	}, nil
}

func (s *LauncherServer) Versions(ctx context.Context, request *pbapi.ServiceVersionsRequest) (*pbapi.ServiceVersionsResponse, error) {
	var versionList []*pbapi.ServiceVersion
	for version := range s.minio.ListObjects(ctx, "releases", minio.ListObjectsOptions{
		WithVersions: true,
		Prefix:       fmt.Sprintf("%s/%s", request.GetChannel(), request.GetId()),
	}) {
		if version.Err != nil {
			return nil, status.Error(codes.Internal, "Failed to fetch version")
		}

		versionList = append(versionList, &pbapi.ServiceVersion{
			Date:     version.LastModified.Format(time.RFC3339),
			Version:  version.VersionID,
			Size:     uint32(version.Size),
			IsLatest: version.IsLatest,
		})
	}

	return &pbapi.ServiceVersionsResponse{
		Versions: versionList,
	}, nil
}

func (s *LauncherServer) DownloadUrl(ctx context.Context, req *pbapi.ServiceVersionDownloadUrlRequest) (*pbapi.ServiceVersionDownloadUrl, error) {
	val := ctx.Value("user")
	user, _ := val.(*models.UserModel)

	if !s.wc.AllowAllChannels && (user == nil || !user.Entitled(models.EntitlementAdmin)) {
		channels := s.wc.Channels[req.GetId()]
		if channels == nil || len(channels) == 0 {
			return nil, status.Error(codes.InvalidArgument, fmt.Sprintf("Object '%s' is not found", req.GetId()))
		}

		if !slices.Contains(channels, req.GetChannel()) {
			return nil, status.Error(codes.InvalidArgument, fmt.Sprintf("Branch '%s' is not allowed", req.GetChannel()))
		}
	}

	params := url.Values{}
	params.Add("versionId", req.GetVersion())

	resp, err := s.minio.PresignedGetObject(ctx, "releases", fmt.Sprintf("%s/%s.zip", req.GetChannel(), req.GetId()), time.Hour*24, params)
	if err != nil {
		logger.L().Error(err.Error())
		return nil, status.Error(codes.Internal, "Failed to get presigned URL")
	}

	return &pbapi.ServiceVersionDownloadUrl{
		Id:      req.GetId(),
		Channel: req.GetChannel(),
		Url:     resp.String(),
	}, nil
}

func (s *LauncherServer) PatronList(ctx context.Context, req *pbcommon.Empty) (*pbapi.PatronListResponse, error) {
	patrons, err := s.store.Users.GetPatronNames(ctx)
	if err != nil {
		logger.L().Error(err.Error())
		return nil, status.Error(codes.Internal, "Failed to get patrons")
	}

	if patrons == nil {
		return nil, status.Error(codes.NotFound, "No patrons found")
	}

	cachedPatrons, err := s.patronsCache.Get(ctx)
	if err != nil {
		logger.L().Error(err.Error())
	}

	if cachedPatrons != nil {
		return &pbapi.PatronListResponse{
			PatronNames: *cachedPatrons,
		}, nil
	}

	if err := s.patronsCache.Set(ctx, patrons); err != nil {
		logger.L().Error(err.Error())
	}

	return &pbapi.PatronListResponse{
		PatronNames: *patrons,
	}, nil
}

var fileSizeLimit int64 = 5 * 1024 * 1024 * 1024

func (s *LauncherServer) UploadMod(stream grpc.BidiStreamingServer[pbapi.ModUploadRequest, pbcommon.Empty]) error {
	ctx := stream.Context()
	user := ctx.Value("user").(*models.UserModel)

	firstReq, err := stream.Recv()
	if err != nil {
		if err == io.EOF {
			return status.Error(codes.InvalidArgument, "no token provided")
		}

		return status.Error(codes.Internal, fmt.Sprintf("failed to receive initial token: %v", err))
	}

	if !user.Entitled(models.EntitlementAdmin) {
		return status.Error(codes.PermissionDenied, "permission denied")
	}

	reader, writer := io.Pipe()
	totalSize := int64(0)
	go func() {
		defer writer.Close()

		if chunk := firstReq.GetChunk(); len(chunk) > 0 {
			if int64(len(chunk)) > fileSizeLimit {
				writer.CloseWithError(status.Error(codes.ResourceExhausted, "file size exceeds limit of 5GB"))
				return
			}

			totalSize += int64(len(chunk))

			if _, err := writer.Write(chunk); err != nil {
				writer.CloseWithError(fmt.Errorf("pipe write: %w", err))
				return
			}

			if err := stream.Send(&pbcommon.Empty{}); err != nil {
				writer.CloseWithError(fmt.Errorf("send initial response: %w", err))
				return
			}
		}

		if firstReq.GetDone() {
			if err := writer.Close(); err != nil {
				writer.CloseWithError(fmt.Errorf("pipe close: %w", err))
				return
			}

			return
		}

		for {
			req, err := stream.Recv()

			if err == io.EOF {
				return
			}

			if req.GetDone() {
				if err := writer.Close(); err != nil {
					writer.CloseWithError(fmt.Errorf("pipe close: %w", err))
					return
				}
			}

			if err != nil {
				writer.CloseWithError(fmt.Errorf("receive from stream: %w", err))
				return
			}

			chunk := req.GetChunk()
			totalSize += int64(len(chunk))

			if int64(len(chunk)) > fileSizeLimit || totalSize > fileSizeLimit {
				writer.CloseWithError(status.Error(codes.ResourceExhausted, "file size exceeds limit of 5GB"))
				return
			}

			if _, err := writer.Write(chunk); err != nil {
				writer.CloseWithError(fmt.Errorf("pipe write: %w", err))
				return
			}

			if err := stream.Send(&pbcommon.Empty{}); err != nil {
				writer.CloseWithError(fmt.Errorf("send response: %w", err))
				return
			}
		}
	}()

	bucketName := "mod-storage"
	objectName := fmt.Sprintf("%s.zip", util.GenerateToken())

	_, err = s.minio.GetObject(ctx, bucketName, objectName, minio.GetObjectOptions{})
	if err != nil {
		return status.Error(codes.Internal, "Failed to check if file exists")
	}

	_, err = s.minio.PutObject(ctx, bucketName, objectName, reader, -1, minio.PutObjectOptions{
		ContentType: "application/octet-stream",
	})
	if err != nil {
		logger.L().Error(err.Error())
		return status.Error(codes.Internal, "Failed to upload file")
	}

	mod := &models.HostedMod{
		ID:         util.GenerateShortToken(),
		FileName:   objectName,
		UploaderID: user.ID,
		Name:       "",
		Version:    "",
		Created:    time.Now(),
		Updated:    time.Now(),
	}

	err = s.store.HostedMods.Create(ctx, mod)
	if err != nil {
		logger.L().Error("Failed to create mod entry", zap.Error(err))
		return status.Error(codes.Internal, "Failed to create mod entry")
	}

	downloadUrl, err := s.minio.PresignedGetObject(ctx, bucketName, objectName, time.Hour*24, nil)
	if err != nil {
		logger.L().Error("Failed to get presigned URL", zap.Error(err))
		return status.Error(codes.Internal, "Failed to get presigned URL")
	}

	if s.amqpCh != nil {
		payload := IndexModByUrlPayload{
			ID:  mod.ID,
			URL: downloadUrl.String(),
		}

		body, err := createTaskMessage("index_mod_by_url", &payload)
		if err != nil {
			logger.L().Error("Failed to create task message", zap.Error(err))
			return status.Error(codes.Internal, "Failed to create task message")
		}

		err = s.amqpCh.Publish("", "mods", false, false, amqp.Publishing{
			Body: body,
		})
	}

	logger.L().Info(fmt.Sprintf("Uploading to MinIO"))

	if err := stream.Send(&pbcommon.Empty{}); err != nil {
		return status.Error(codes.Internal, "Failed to send final response")
	}

	return nil
}

func (s *LauncherServer) fetchMod(ctx context.Context, item *pbapi.HostedModQueryItem, region *string) (*pbapi.HostedModResponseItem, error) {
	mod, err := s.store.HostedMods.Search(context.Background(), item.GetName(), item.GetVersion())
	if err != nil {
		logger.L().Error(err.Error())
		return nil, status.Error(codes.Internal, "Failed to get mod")
	}

	if mod == nil {
		return nil, status.Error(codes.NotFound, "Mod not found")
	}

	storage := s.getModStorage(region)
	if storage == nil {
		return nil, status.Error(codes.Internal, "No CDN configured")
	}

	if storage.IsPublic {
		u, err := url.Parse(fmt.Sprintf("https://%s/%s/%s", storage.Host, storage.Bucket, mod.FileName))
		if err != nil {
			logger.L().Error(err.Error())
			return nil, status.Error(codes.Internal, "Failed to parse CDN URL")
		}

		return &pbapi.HostedModResponseItem{
			Name:    mod.Name,
			Version: mod.Version,
			Size:    mod.TotalSize,
			Url:     u.String(),
		}, nil
	}

	u, err := s.minio.PresignedGetObject(ctx, "mod-storage", mod.FileName, time.Hour*24, nil)
	if err != nil {
		logger.L().Error(err.Error())
		return nil, status.Error(codes.Internal, "Failed to get presigned URL")
	}

	return &pbapi.HostedModResponseItem{
		Name:    mod.Name,
		Version: mod.Version,
		Size:    mod.TotalSize,
		Url:     u.String(),
	}, nil
}

func (s *LauncherServer) getModStorage(region *string) *ModStorage {
	var storage *ModStorage
	if region != nil {
		for _, c := range s.launcherConfig.ModStorage {
			if c.Region == *region {
				storage = &c
				break
			}
		}
	}

	if storage == nil {
		for _, c := range s.launcherConfig.ModStorage {
			if c.ID == s.launcherConfig.DefaultModStorage {
				storage = &c
				break
			}
		}
	}

	return storage
}

type IndexModByUrlPayload struct {
	ID  string `json:"id"`
	URL string `json:"url"`
}

func (p *IndexModByUrlPayload) ToBincode() ([]byte, error) {
	buf := new(bytes.Buffer)

	if err := binary.Write(buf, binary.LittleEndian, uint64(len(p.ID))); err != nil {
		return nil, fmt.Errorf("write id length: %w", err)
	}
	if _, err := buf.Write([]byte(p.ID)); err != nil {
		return nil, fmt.Errorf("write id bytes: %w", err)
	}

	if err := binary.Write(buf, binary.LittleEndian, uint64(len(p.URL))); err != nil {
		return nil, fmt.Errorf("write url length: %w", err)
	}
	if _, err := buf.Write([]byte(p.URL)); err != nil {
		return nil, fmt.Errorf("write url bytes: %w", err)
	}

	return buf.Bytes(), nil
}

func createTaskMessage(method string, payload *IndexModByUrlPayload) ([]byte, error) {
	body, err := payload.ToBincode()
	if err != nil {
		return nil, err
	}

	msg := new(bytes.Buffer)
	msg.WriteString(method)
	msg.WriteByte(0)
	msg.Write(body)
	return msg.Bytes(), nil
}
