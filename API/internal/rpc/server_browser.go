package rpc

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"slices"
	"time"

	"github.com/ArmchairDevelopers/Kyber/API/api/v1/pbapi"
	"github.com/ArmchairDevelopers/Kyber/API/api/v1/pbcommon"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/db"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/jwts"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/logger"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/models"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/mq"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/util"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/ws"
	"github.com/TwiN/go-away"
	"github.com/go-playground/validator/v10"
	"github.com/golang-jwt/jwt/v5"
	amqp "github.com/rabbitmq/amqp091-go"
	"go.mongodb.org/mongo-driver/bson"
	"go.uber.org/zap"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
)

type ServerBrowserServer struct {
	store    *db.Store
	sm       *ws.ServerManager
	jwt      *jwts.Service
	mqClient mq.Client
	pbapi.UnimplementedServerBrowserServer
}

func (s *ServerBrowserServer) cleanupStaleServers() {
	for {
		func() {
			defer func() {
				if r := recover(); r != nil {
					logger.L().Error("cleanupStaleServers panicked; restarting", zap.Any("panic", r))
				}
			}()

			ticker := time.NewTicker(10 * time.Second)
			defer ticker.Stop()

			for range ticker.C {
				cutoff := time.Now().Add(-40 * time.Second)
				ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
				servers, err := s.store.Servers.GetWithCutoff(ctx, cutoff)

				cancel()

				if err != nil {
					logger.L().Error("Failed to get servers with cutoff", zap.Error(err))
					continue
				}

				if len(servers) == 0 {
					continue
				}

				ids := make([]string, len(servers))
				for i, srv := range servers {
					ids[i] = srv.ID
				}

				ctx, cancel = context.WithTimeout(context.Background(), 5*time.Second)
				if err := s.store.Servers.DeleteMany(ctx, ids); err != nil {
					cancel()
					logger.L().Error("Failed to delete servers", zap.Error(err))
					continue
				}

				cancel()

				cnvIds := make([]*string, len(ids))
				for i, s := range servers {
					cnvIds[i] = &s.ID
				}

				s.publishKronosUpdate(ctx, models.KronosServerUpdate{ServersDeleted: cnvIds})

				for _, id := range ids {
					m := ws.NewStatusStaleServer()
					msg := ws.APIManagementMessage{ServerID: id, Status: &m}
					s.sm.PublishWS(msg, id)
				}

				logger.L().Debug("Deleted stale servers", zap.Int("count", len(ids)))
			}
		}()

		logger.L().Error("cleanup loop exited unexpectedly, restarting")
	}
}

func NewServerBrowserServer(store *db.Store, sm *ws.ServerManager, client mq.Client, jwt *jwts.Service) *ServerBrowserServer {
	srv := &ServerBrowserServer{
		store:    store,
		sm:       sm,
		mqClient: client,
		jwt:      jwt,
	}

	go srv.cleanupStaleServers()

	return srv
}

func (s *ServerBrowserServer) CheckModImages(ctx context.Context, req *pbapi.CheckModImagesRequest) (*pbapi.CheckModImagesResponse, error) {
	if len(req.GetItems()) == 0 {
		return nil, status.Error(codes.InvalidArgument, "No images provided")
	}

	existing := make([]string, 0)

	ids := make([]string, 0, len(req.GetItems()))
	for _, item := range req.GetItems() {
		ids = append(ids, item.GetHash())
	}

	resp, err := s.store.ModImages.GetBulkByIDs(ctx, ids)
	if err != nil {
		logger.L().Error("Failed to get image hashes", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get image hashes")
	}

	for _, image := range resp {
		if image == nil {
			continue
		}

		var itemEntry *pbapi.CheckModImageItem
		for _, item := range req.GetItems() {
			if item.GetHash() == image.ID {
				itemEntry = item
				break
			}
		}

		// just in case
		if itemEntry == nil {
			logger.L().Warn("Image hash not found in request items", zap.String("hash", image.ID))
			continue
		}

		updated := false
		if !slices.Contains(image.Levels, itemEntry.GetLevel()) {
			image.Levels = append(image.Levels, itemEntry.GetLevel())
			updated = true
		}

		if !slices.Contains(image.Modes, itemEntry.GetMode()) {
			image.Modes = append(image.Modes, itemEntry.GetMode())
			updated = true
		}

		if updated {
			if err := s.store.ModImages.Update(ctx, image.ID, bson.M{
				"$set": bson.M{
					"levels": image.Levels,
					"modes":  image.Modes,
				},
			}); err != nil {
				logger.L().Error("Failed to update image hash", zap.Error(err))
				return nil, status.Error(codes.Internal, "Failed to update image hash")
			}
		}

		existing = append(existing, image.ID)
	}

	return &pbapi.CheckModImagesResponse{Hashes: existing}, nil
}

func (s *ServerBrowserServer) UploadModImages(ctx context.Context, req *pbapi.UploadModImagesRequest) (*pbcommon.Empty, error) {
	user := ctx.Value("user").(*models.UserModel)

	// why tf does this panic in the first place
	defer func() {
		if r := recover(); r != nil {
			logger.L().Error(
				"panic in UploadModImages",
				zap.Any("panic", r),
				zap.Stack("stacktrace"),
			)
		}
	}()

	if len(req.GetImages()) >= 30 {
		return nil, status.Error(codes.InvalidArgument, "Too many images provided")
	}

	for _, img := range req.GetImages() {
		if len(img.GetImage()) == 0 {
			return nil, status.Error(codes.InvalidArgument, "Image data is empty")
		}

		if img.GetLevel() == "" {
			return nil, status.Error(codes.InvalidArgument, "Image name is empty")
		}

		hash, err := util.GenerateImageHash(img.GetImage())
		if err != nil {
			logger.L().Error("Failed to generate image hash", zap.Error(err))
			return nil, status.Error(codes.Internal, "Failed to generate image hash")
		}

		existing, err := s.store.ModImages.GetByID(ctx, hash)
		if err != nil {
			logger.L().Error("Failed to get image hash", zap.Error(err))
			return nil, status.Error(codes.Internal, "Failed to get image hash")
		}

		convertedMod := models.ModImageModModel{
			Name:    img.GetMod().GetName(),
			Version: img.GetMod().GetVersion(),
		}

		if existing != nil {
			if !slices.Contains(existing.Mods, convertedMod) {
				existing.Mods = append(existing.Mods, convertedMod)
			}

			if !slices.Contains(existing.Levels, img.GetLevel()) {
				existing.Levels = append(existing.Levels, img.GetLevel())
			}

			if !slices.Contains(existing.Modes, img.GetMode()) {
				existing.Modes = append(existing.Modes, img.GetMode())
			}

			if err := s.store.ModImages.Update(ctx, existing.ID, bson.M{"$set": bson.M{"mods": existing.Mods, "levels": existing.Levels, "modes": existing.Modes}}); err != nil {
				logger.L().Error("Failed to update existing image hash", zap.Error(err))
				return nil, status.Error(codes.Internal, "Failed to update existing image hash")
			}

			continue
		}

		imageStatus := models.ImageHashStatusPending
		if user.Entitled(models.EntitlementAutoApproveModImages) {
			imageStatus = models.ImageHashStatusApproved

			err = s.mqClient.Channel.Publish("image_hashes", "", false, false, amqp.Publishing{
				Body:        []byte(hash),
				ContentType: "text/plain",
			})

			if err != nil {
				logger.L().Error("Failed to publish image hash to queue", zap.Error(err))
				return nil, status.Error(codes.Internal, "Failed to publish image hash")
			}
		}

		image := models.ModImageModel{
			ID:        hash,
			Data:      img.GetImage(),
			Levels:    []string{img.GetLevel()},
			Modes:     []string{img.GetMode()},
			Mods:      []models.ModImageModModel{convertedMod},
			Status:    imageStatus,
			UseCount:  1,
			CreatedAt: time.Now(),
			LastUsed:  time.Now(),
		}

		if err := s.store.ModImages.Create(ctx, &image); err != nil {
			logger.L().Error("Failed to create image hash", zap.Error(err))
			return nil, status.Error(codes.Internal, "Failed to create image hash")
		}
	}

	return &pbcommon.Empty{}, nil
}

func (s *ServerBrowserServer) GetServers(ctx context.Context, _ *pbapi.ServerListRequest) (*pbapi.ServerList, error) {
	servers, err := s.store.Servers.GetPublic(ctx)
	if err != nil {
		logger.L().Error("Failed to get public servers", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get servers")
	}

	if servers == nil {
		return &pbapi.ServerList{
			Servers: []*pbapi.Server{},
		}, nil
	}

	cs := make([]*pbapi.Server, 0)
	for _, server := range servers {
		cs = append(cs, server.Proto())
	}

	return &pbapi.ServerList{
		Servers: cs,
	}, nil
}

func (s *ServerBrowserServer) GetServer(ctx context.Context, req *pbapi.ServerRequest) (*pbapi.Server, error) {
	server, err := s.store.Servers.GetByID(ctx, req.GetId())
	if err != nil {
		logger.L().Error("Failed to get server", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get server")
	}

	if server == nil {
		return nil, status.Error(codes.NotFound, "Server not found")
	}

	return server.Proto(), nil
}

func (s *ServerBrowserServer) UpdateServer(ctx context.Context, req *pbapi.UpdateServerRequest) (*pbcommon.Empty, error) {
	user := ctx.Value("user").(*models.UserModel)

	server, err := s.store.Servers.GetByID(ctx, req.GetId())
	if err != nil {
		return nil, status.Error(codes.Internal, "Failed to get server")
	}

	if server == nil {
		return nil, status.Error(codes.NotFound, "Server not found")
	}

	host, err := s.store.Users.GetByID(ctx, server.HostID)
	if err != nil {
		return nil, status.Error(codes.Internal, "Failed to get host")
	}

	if host == nil {
		return nil, status.Error(codes.Internal, "Host not found")
	}

	isModerator := slices.Contains(host.ModeratorUserIDs, user.ID)
	if server.HostID != user.ID && !isModerator && !user.Entitled(models.EntitlementGlobalServerModerator) {
		return nil, status.Error(codes.PermissionDenied, "User is not the host of the server")
	}

	if req.GetName() != "" {
		if goaway.IsProfane(req.GetName()) {
			return nil, status.Error(codes.InvalidArgument, "Server name contains profanity")
		}

		server.Name = req.GetName()
	}

	if req.Password != nil {
		if req.GetPassword() != "" {
			server.Password = req.Password
		} else {
			server.Password = nil
		}
	}

	if req.Description != nil {
		if req.GetDescription() != "" {
			server.Description = req.Description
		} else {
			server.Description = nil
		}
	}

	if req.GetLevelSetup() != nil {
		server.LevelSetup.Map = req.GetLevelSetup().GetMap()
		server.LevelSetup.Mode = req.GetLevelSetup().GetMode()

		if req.GetLevelSetup().GetMapName() != "" {
			cnvMods := make([]models.ModImageModModel, 0, len(server.ExplodedMods))
			for _, mod := range server.ExplodedMods {
				cnvMods = append(cnvMods, models.ModImageModModel{
					Name:    mod.Name,
					Version: mod.Version,
				})
			}

			imageHash, err := s.getServerMapImage(ctx, req.GetLevelSetup(), cnvMods)
			if err != nil {
				return nil, err
			}

			server.LevelSetup.ImageHash = imageHash
		}
	}

	if err := server.Validate(); err != nil {
		var ve *validator.ValidationErrors
		if errors.As(err, &ve) {
			return nil, status.Error(codes.InvalidArgument, ve.Error())
		}

		logger.L().Error("Failed to validate server", zap.Error(err))
		return nil, status.Error(codes.InvalidArgument, "Invalid server data")
	}

	err = s.store.Servers.UpdateByID(ctx, server.ID, bson.M{
		"$set": bson.M{
			"name":                   server.Name,
			"password":               server.Password,
			"description":            server.Description,
			"level_setup.map":        server.LevelSetup.Map,
			"level_setup.mode":       server.LevelSetup.Mode,
			"level_setup.map_name":   server.LevelSetup.MapName,
			"level_setup.mode_name":  server.LevelSetup.ModeName,
			"level_setup.image_hash": server.LevelSetup.ImageHash,
			"last_updated":           time.Now(),
			"max_player_count":       server.MaxPlayerCount,
		},
	})
	if err != nil {
		logger.L().Error("Failed to update server", zap.String("id", server.ID), zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to update server")
	}

	s.publishKronosUpdate(ctx, models.KronosServerUpdate{ServerUpdated: server})

	return &pbcommon.Empty{}, nil
}

func (s *ServerBrowserServer) ValidateServer(_ context.Context, req *pbapi.RegisterServerRequest) (*pbcommon.Empty, error) {
	server := models.ServerModel{
		Name:           req.GetName(),
		Password:       req.Password,
		Description:    req.Description,
		MaxPlayerCount: req.GetMaxPlayerCount(),
		LevelSetup: models.LevelSetupModel{
			Map:      req.GetLevelSetup().GetMap(),
			Mode:     req.GetLevelSetup().GetMode(),
			MapName:  util.ToPtr(req.GetLevelSetup().GetMapName()),
			ModeName: util.ToPtr(req.GetLevelSetup().GetModeName()),
		},
	}

	if err := server.Validate(); err != nil {
		var ve *validator.ValidationErrors
		if errors.As(err, &ve) {
			return nil, status.Error(codes.InvalidArgument, ve.Error())
		}

		logger.L().Error("Failed to validate server", zap.Error(err))
		return nil, err
	}

	return &pbcommon.Empty{}, nil
}

func (s *ServerBrowserServer) RegisterServer(ctx context.Context, req *pbapi.RegisterServerRequest) (*pbapi.RegisterServerResponse, error) {
	meta, exist := metadata.FromIncomingContext(ctx)
	if !exist {
		return nil, status.Error(codes.Unauthenticated, "Missing metadata")
	}

	addr := meta.Get("cf-connecting-ip")
	if len(addr) == 0 {
		return nil, status.Error(codes.Unauthenticated, "Missing IP address")
	}

	user := ctx.Value("user").(*models.UserModel)

	hostedServers, err := s.store.Servers.GetByHostID(ctx, user.ID)
	if err != nil {
		logger.L().Error("Failed to get hosted servers", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get hosted servers")
	}

	if len(hostedServers) >= user.GetServerLimit() {
		return nil, status.Error(codes.PermissionDenied, fmt.Sprintf("You have reached your server hosting limit of %d server", user.GetServerLimit()))
	}

	if len(req.GetMeta()) > 0 && !user.Entitled(models.EntitlementVerifiedServers) {
		return nil, status.Error(codes.PermissionDenied, "User is not entitled to use meta data")
	}

	mods := make([]models.ServerModModel, 0)
	for _, mod := range req.GetMods() {
		link := mod.GetLink()
		mods = append(mods, models.ServerModModel{
			Name:     mod.GetName(),
			Version:  mod.GetVersion(),
			Link:     &link,
			FileSize: mod.GetFileSize(),
		})
	}

	explodedMods := make([]models.ServerModModel, 0)
	for _, mod := range req.GetExplodedMods() {
		link := mod.GetLink()
		explodedMods = append(explodedMods, models.ServerModModel{
			Name:     mod.GetName(),
			Version:  mod.GetVersion(),
			Link:     &link,
			FileSize: mod.GetFileSize(),
		})
	}

	var imageHash *string
	if req.GetLevelSetup().GetMapName() != "" {
		cnvMods := make([]models.ModImageModModel, 0, len(req.GetExplodedMods()))
		for _, mod := range req.GetExplodedMods() {
			cnvMods = append(cnvMods, models.ModImageModModel{
				Name:    mod.GetName(),
				Version: mod.GetVersion(),
			})
		}

		imageHash, err = s.getServerMapImage(ctx, req.GetLevelSetup(), cnvMods)
	}

	serverID := util.GenerateToken()

	serverJWT := &models.ServerJWT{
		UserID:   user.ID,
		ServerID: serverID,
		RegisteredClaims: jwt.RegisteredClaims{
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(30 * 24 * time.Hour)),
		},
	}

	proxyToken, err := s.jwt.SignToken(serverJWT)
	if err != nil {
		logger.L().Error(err.Error())
		return nil, status.Error(codes.Internal, "Failed to sign join token")
	}

	joinToken := &models.JoinTokenModel{
		ID:      util.GenerateShortToken(),
		Token:   proxyToken,
		User:    user.ID,
		Server:  serverID,
		Created: time.Now(),
	}

	err = s.store.JoinTokens.Create(ctx, joinToken)
	if err != nil {
		logger.L().Error(err.Error())
		return nil, status.Error(codes.Internal, "Failed to create join token")
	}

	var hostRegion *string
	if meta.Get("cf-ipcontinent") != nil && len(meta.Get("cf-ipcontinent")) > 0 {
		hostRegion = &meta.Get("cf-ipcontinent")[0]
	}

	server := models.ServerModel{
		ID:             serverID,
		Name:           req.GetName(),
		Password:       req.Password,
		Description:    req.Description,
		Dedicated:      req.GetDedicated(),
		MetaData:       req.GetMeta(),
		Host:           user.Name,
		HostID:         user.ID,
		Mods:           mods,
		ExplodedMods:   explodedMods,
		Official:       user.Entitled(models.EntitlementOfficialServers),
		Verified:       user.Entitled(models.EntitlementVerifiedServers),
		HostToken:      user.Token,
		LastUpdated:    time.Now(),
		MaxPlayerCount: req.GetMaxPlayerCount(),
		PlayerCount:    0,
		HostRegion:     hostRegion,
		HostAddress: models.NetworkAddress{
			IP:   addr[0],
			Port: 25200,
		},
		LevelSetup: models.LevelSetupModel{
			Map:       req.GetLevelSetup().GetMap(),
			Mode:      req.GetLevelSetup().GetMode(),
			MapName:   util.ToPtr(req.GetLevelSetup().GetMapName()),
			ModeName:  util.ToPtr(req.GetLevelSetup().GetModeName()),
			ImageHash: imageHash,
		},
		ProxyToken: proxyToken,
	}

	if err := server.Validate(); err != nil {
		var ve *validator.ValidationErrors
		if errors.As(err, &ve) {
			return nil, status.Error(codes.InvalidArgument, ve.Error())
		}

		logger.L().Error("Failed to validate server", zap.Error(err))
		return nil, err
	}

	_, err = s.store.Servers.Create(ctx, &server)
	if err != nil {
		return nil, status.Error(codes.Internal, "Failed to create server")
	}

	err = s.store.Users.Update(ctx, user.ID, bson.M{"$inc": bson.M{"metric_data.servers_hosted": 1}})
	if err != nil {
		logger.L().Error("Failed to update user", zap.Error(err))
	}

	s.publishKronosUpdate(ctx, models.KronosServerUpdate{ServerCreated: &server})

	logger.L().Info("Created server", zap.String("id", server.ID))
	return ConvertServerToProto(&server), nil
}

func (s *ServerBrowserServer) getServerMapImage(ctx context.Context, levelSetup *pbcommon.LevelSetup, mods []models.ModImageModModel) (*string, error) {
	image, err := s.store.ModImages.SearchMapImage(ctx, levelSetup.GetMap(), levelSetup.GetMode(), mods)
	if err != nil {
		logger.L().Error("Failed to search for image hash", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to search for image hash")
	}

	if image == nil {
		// maybe error here?
		return nil, nil
	}

	if err = s.store.ModImages.Update(ctx, image.ID, bson.M{
		"$inc": bson.M{"use_count": 1},
		"$set": bson.M{"last_used": time.Now()},
	}); err != nil {
		logger.L().Error("Failed to update image hash", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to update image hash")
	}

	if image.Status == models.ImageHashStatusRejected {
		return nil, nil
	}

	if image.Status != models.ImageHashStatusApproved {
		if image.UseCount+1 >= 1 {
			err = s.mqClient.Channel.Publish("image_hashes", "", false, false, amqp.Publishing{
				Body:        []byte(image.ID),
				ContentType: "text/plain",
			})

			if err != nil {
				logger.L().Error("Failed to publish image hash to queue", zap.Error(err))
				return nil, status.Error(codes.Internal, "Failed to publish image hash")
			}
		}

		return nil, nil
	}

	imageHash := &image.ID

	return imageHash, nil
}

func (s *ServerBrowserServer) CanJoinServer(ctx context.Context, req *pbapi.CanJoinServerRequest) (*pbapi.CanJoinServerResponse, error) {
	user := ctx.Value("user").(*models.UserModel)

	server, err := s.store.Servers.GetByID(ctx, req.GetId())
	if err != nil {
		return nil, status.Error(codes.Internal, "Failed to get server")
	}

	if server == nil {
		return nil, status.Error(codes.NotFound, "Server not found")
	}

	if server.Password != nil && *server.Password != req.GetPassword() {
		reason := "Invalid Password"
		return &pbapi.CanJoinServerResponse{
			CanJoin: false,
			Reason:  &reason,
		}, nil
	}

	ban, err := s.store.Punishments.GetBanForServer(ctx, server.HostID, user.ID)
	if err != nil {
		return nil, status.Error(codes.Internal, "Failed to check ban")
	}

	if ban != nil {
		reason := fmt.Sprintf("You are banned from this server: %s", *ban.Reason)
		return &pbapi.CanJoinServerResponse{
			CanJoin: false,
			Reason:  &reason,
		}, nil
	}

	return &pbapi.CanJoinServerResponse{
		CanJoin: true,
	}, nil
}

func ConvertServerToProto(server *models.ServerModel) *pbapi.RegisterServerResponse {
	mods := make([]*pbcommon.ServerMod, len(server.Mods))
	for i, mod := range server.Mods {
		mods[i] = &pbcommon.ServerMod{
			Name:     mod.Name,
			Version:  mod.Version,
			Link:     mod.Link,
			FileSize: mod.FileSize,
		}
	}

	return &pbapi.RegisterServerResponse{
		Name:        server.Name,
		Description: server.Description,
		LevelSetup: &pbcommon.LevelSetup{
			Mode:     server.LevelSetup.Mode,
			Map:      server.LevelSetup.Map,
			ModeName: server.LevelSetup.ModeName,
			MapName:  server.LevelSetup.MapName,
		},
		PlayerCount:      server.PlayerCount,
		MaxPlayerCount:   server.MaxPlayerCount,
		Official:         server.Official,
		Port:             nil,
		Mods:             mods,
		Id:               server.ID,
		Ip:               nil,
		Meta:             server.MetaData,
		Creator:          server.Host,
		CreatorId:        server.HostID,
		RequiresPassword: server.Password != nil && len(*server.Password) > 0,
		RequiresProxy:    true,
		Region:           server.HostRegion,
		MapImageHash:     server.LevelSetup.ImageHash,
		ProxyToken:       server.ProxyToken,
	}
}

func (s *ServerBrowserServer) publishKronosUpdate(ctx context.Context, update models.KronosServerUpdate) {
	body, err := json.Marshal(update)
	if err != nil {
		logger.L().Error(err.Error())
		return
	}

	if err = s.mqClient.Channel.Publish(
		"kronos_server_browser",
		"",
		false,
		false,
		amqp.Publishing{
			ContentType: "application/json",
			Body:        body,
		},
	); err != nil {
		logger.L().Error(err.Error())
	}
}
