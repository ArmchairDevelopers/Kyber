package rpc

import (
	"context"
	"fmt"
	"slices"
	"time"

	"github.com/ArmchairDevelopers/Kyber/API/api/v1/pbapi"
	"github.com/ArmchairDevelopers/Kyber/API/api/v1/pbcommon"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/db"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/logger"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/models"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/util"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/ws"
	"go.mongodb.org/mongo-driver/bson"
	"go.uber.org/zap"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

type ServerManagement struct {
	store *db.Store
	sm    *ws.ServerManager
	pbapi.UnimplementedServerManagementServer
}

func NewServerManagementServer(store *db.Store, sm *ws.ServerManager) *ServerManagement {
	return &ServerManagement{
		store: store,
		sm:    sm,
	}
}

func (s *ServerManagement) UnbanPlayer(ctx context.Context, req *pbapi.UnbanPlayerRequest) (*pbcommon.Empty, error) {
	server, user, err := s.isModerator(ctx, req.GetServerId())
	if err != nil {
		return nil, err
	}

	punishment, err := s.store.Punishments.GetBanForServer(ctx, server.HostID, req.GetUserId())
	if err != nil {
		logger.L().Error("Failed to get punishment", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get punishment")
	}

	if punishment == nil {
		return nil, status.Error(codes.NotFound, "Punishment not found")
	}

	punishment.OverturnedBy = &user.ID
	err = s.store.Punishments.Update(ctx, punishment)
	if err != nil {
		logger.L().Error("Failed to update punishment", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to update punishment")
	}

	return &pbcommon.Empty{}, nil
}

func (s *ServerManagement) GetPunishments(ctx context.Context, req *pbapi.PunishmentsRequest) (*pbapi.PunishmentsResponse, error) {
	server, _, err := s.isModerator(ctx, req.GetServerId())
	if err != nil {
		return nil, err
	}

	punishments, err := s.store.Punishments.GetBansForServer(ctx, server.HostID)
	if err != nil {
		logger.L().Error("Failed to get punishments", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get punishments")
	}

	bannedUserIDs := make([]string, 0)
	for _, punishment := range punishments {
		if !slices.Contains(bannedUserIDs, *punishment.User) {
			bannedUserIDs = append(bannedUserIDs, *punishment.User)
		}
	}

	users, err := s.store.Users.SearchByIDs(ctx, bannedUserIDs)
	if err != nil {
		logger.L().Error("Failed to get users", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get users")
	}

	convPunishments := make([]*pbapi.Punishment, 0)
	for _, punishment := range punishments {
		var user *models.UserModel
		for _, u := range users {
			if *punishment.User == u.ID {
				user = u
				break
			}
		}

		if user == nil {
			continue
		}

		punishment.UserModel = user

		convPunishments = append(convPunishments, punishment.Proto())
	}

	return &pbapi.PunishmentsResponse{
		Punishments: convPunishments,
	}, nil
}

func (s *ServerManagement) GetModerators(ctx context.Context, req *pbapi.ModeratorsRequest) (*pbapi.ModeratorList, error) {
	user := ctx.Value("user").(*models.UserModel)

	server, err := s.store.Servers.GetByID(ctx, req.GetServerId())
	if err != nil {
		logger.L().Error("Failed to get server by ID", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get server")
	}

	if server == nil {
		return nil, status.Error(codes.NotFound, "Server not found")
	}

	host, err := s.store.Users.GetByID(ctx, server.HostID)
	if err != nil {
		logger.L().Error("Failed to get server host", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get server host")
	}

	if host == nil {
		return nil, status.Error(codes.NotFound, "Server host not found")
	}

	if !server.CanManage(host, user) {
		return nil, status.Error(codes.PermissionDenied, "You are not a moderator of this server")
	}

	users, err := s.store.Users.SearchByIDs(ctx, host.ModeratorUserIDs)
	if err != nil {
		logger.L().Error("Failed to get moderator users", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get moderator users")
	}

	cnv := make([]*pbcommon.KyberPlayer, len(users))
	for i, u := range users {
		cnv[i] = &pbcommon.KyberPlayer{
			Id:   u.ID,
			Name: u.Name,
		}
	}

	return &pbapi.ModeratorList{Users: cnv}, nil
}

func (s *ServerManagement) AddModerator(ctx context.Context, req *pbapi.AddModeratorRequest) (*pbcommon.Empty, error) {
	user := ctx.Value("user").(*models.UserModel)

	if slices.Contains(user.ModeratorUserIDs, req.GetId()) {
		return nil, status.Error(codes.AlreadyExists, "User is already a moderator")
	}

	moderator, err := s.store.Users.GetByID(ctx, req.GetId())
	if err != nil {
		logger.L().Error("Failed to get user by ID", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get user")
	}

	if moderator == nil {
		return nil, status.Error(codes.NotFound, "User not found")
	}

	user.ModeratorUserIDs = append(user.ModeratorUserIDs, moderator.ID)

	err = s.store.Users.Update(ctx, user.ID, bson.M{"$set": bson.M{"moderator_user_ids": user.ModeratorUserIDs}})
	if err != nil {
		logger.L().Error("Failed to update user", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to update user")
	}

	return &pbcommon.Empty{}, nil
}

func (s *ServerManagement) RemoveModerator(ctx context.Context, req *pbapi.RemoveModeratorRequest) (*pbcommon.Empty, error) {
	user := ctx.Value("user").(*models.UserModel)

	moderatorIndex := slices.Index(user.ModeratorUserIDs, req.GetId())
	if moderatorIndex == -1 {
		return nil, status.Error(codes.NotFound, "User is not a moderator")
	}

	user.ModeratorUserIDs = append(user.ModeratorUserIDs[:moderatorIndex], user.ModeratorUserIDs[moderatorIndex+1:]...)

	err := s.store.Users.Update(ctx, user.ID, bson.M{"$set": bson.M{"moderator_user_ids": user.ModeratorUserIDs}})
	if err != nil {
		logger.L().Error("Failed to update user", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to update user")
	}

	return &pbcommon.Empty{}, nil
}

func (s *ServerManagement) RunCommand(ctx context.Context, req *pbapi.ServerRunCommandRequest) (*pbcommon.Empty, error) {
	server, user, err := s.isModerator(ctx, req.GetId())
	if err != nil {
		return nil, err
	}

	logger.L().Info("User is running command on server", zap.String("user_id", user.ID), zap.String("server_id", server.ID), zap.String("command", req.GetCommand()))

	s.sm.RunCommand(server.ID, req.GetCommand())

	consoleMessage := fmt.Sprintf("[MODERATOR] %s (%s) ran command: %s", user.Name, user.ID, req.GetCommand())
	s.sm.PublishConsoleMessage(server.ID, consoleMessage, false)

	return &pbcommon.Empty{}, nil
}

func (s *ServerManagement) KickPlayer(ctx context.Context, req *pbapi.ServerKickPlayerRequest) (*pbcommon.Empty, error) {
	server, _, err := s.isModerator(ctx, req.GetId())
	if err != nil {
		return nil, err
	}

	target, err := s.store.Users.GetByID(ctx, req.GetUserId())
	if err != nil {
		logger.L().Error("Failed to get user by ID", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get target user")
	}

	if target == nil {
		logger.L().Error("Failed to get target user: user not found", zap.String("user_id", req.GetUserId()), zap.String("server_id", req.GetId()))
		return nil, status.Error(codes.NotFound, "Target user not found")
	}

	if target.ID == server.HostID {
		return nil, status.Error(codes.PermissionDenied, "You cannot kick the server host")
	}

	err = s.store.Punishments.Create(ctx, &models.PunishmentModel{
		ID:        util.GenerateShortToken(),
		Issuer:    &server.HostID,
		User:      &target.ID,
		Reason:    util.ToPtr(req.GetReason()),
		Type:      models.PunishmentTypeKick,
		ExpiresAt: nil,
		IssuedAt:  time.Now(),
	})

	if err != nil {
		logger.L().Error("Failed to create punishment", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to create punishment")
	}

	s.sm.KickPlayer(server.ID, target.ID, req.GetReason())

	return &pbcommon.Empty{}, nil
}

func (s *ServerManagement) BanPlayer(ctx context.Context, req *pbapi.ServerBanPlayerRequest) (*pbcommon.Empty, error) {
	server, _, err := s.isModerator(ctx, req.GetId())
	if err != nil {
		return nil, err
	}

	target, err := s.store.Users.GetByID(ctx, req.GetUserId())
	if err != nil {
		logger.L().Error("Failed to get user by ID", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get target user")
	}

	if target == nil {
		logger.L().Error("Failed to get target user: user not found", zap.String("user_id", req.GetUserId()), zap.String("server_id", req.GetId()))
		return nil, status.Error(codes.NotFound, "Target user not found")
	}

	if target.ID == server.HostID {
		return nil, status.Error(codes.PermissionDenied, "You cannot ban the server host")
	}

	activeBan, err := s.store.Punishments.GetBanForServer(ctx, server.HostID, target.ID)
	if err != nil {
		logger.L().Error("Failed to check punishment", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to check punishments")
	}

	if activeBan != nil {
		return nil, status.Error(codes.PermissionDenied, "User is already banned")
	}

	var expiresAt *time.Time
	if req.Duration != nil && req.GetDuration() > 0 {
		expiresAt = new(time.Time)
		*expiresAt = time.Now().Add(time.Duration(*req.Duration) * time.Second)
	}

	err = s.store.Punishments.Create(ctx, &models.PunishmentModel{
		ID:        util.GenerateShortToken(),
		Issuer:    &server.HostID,
		User:      &target.ID,
		Reason:    util.ToPtr(req.GetReason()),
		Type:      models.PunishmentTypeBan,
		ExpiresAt: expiresAt,
		IssuedAt:  time.Now(),
	})

	if err != nil {
		logger.L().Error("Failed to create punishment", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to create punishment")
	}

	s.sm.KickPlayer(server.ID, target.ID, req.GetReason())

	return &pbcommon.Empty{}, nil
}

func (s *ServerManagement) ModeratedServers(ctx context.Context, _ *pbcommon.Empty) (*pbapi.ServerList, error) {
	user := ctx.Value("user").(*models.UserModel)

	var err error
	ids := make([]string, 0)
	if user.Entitled(models.EntitlementGlobalServerModerator) {
		ids, err = s.store.Servers.GetIDs(ctx)
		if err != nil {
			logger.L().Error("Failed to get server ids", zap.Error(err))
			return nil, status.Error(codes.Internal, "Failed to get server IDs")
		}
	} else if user.Entitled(models.EntitlementOfficialServerModerator) {
		officialServers, err := s.store.Servers.GetByDoc(ctx, bson.M{"official": true})
		if err != nil {
			logger.L().Error("Failed to get official servers", zap.Error(err))
			return nil, status.Error(codes.Internal, "Failed to get official servers")
		}

		for _, server := range officialServers {
			ids = append(ids, server.ID)
		}
	} else {
		ids, err = s.store.Users.ModeratedServers(ctx, user.ID)
		if err != nil {
			logger.L().Error("Failed to get server IDs", zap.Error(err))
			return nil, status.Error(codes.Internal, "Failed to get moderated servers")
		}
	}

	servers, err := s.store.Servers.GetByIDs(ctx, ids)
	if err != nil {
		logger.L().Error("Failed to get servers", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get servers")
	}

	convertedServers := make([]*pbapi.Server, 0)
	for _, server := range servers {
		convertedServers = append(convertedServers, server.Proto())
	}

	return &pbapi.ServerList{
		Servers: convertedServers,
		Page:    1,
		Pages:   1,
	}, nil
}

func (s *ServerManagement) isModerator(ctx context.Context, serverID string) (*models.ServerModel, *models.UserModel, error) {
	user := ctx.Value("user").(*models.UserModel)

	server, err := s.store.Servers.GetByID(ctx, serverID)
	if err != nil {
		logger.L().Error("Failed to get server by ID", zap.Error(err))
		return nil, nil, status.Error(codes.Internal, "Failed to get server")
	}

	if server == nil {
		return nil, nil, status.Error(codes.NotFound, "Server not found")
	}

	host, err := s.store.Users.GetByID(ctx, server.HostID)
	if err != nil {
		logger.L().Error("Failed to get server host", zap.Error(err))
		return nil, nil, status.Error(codes.Internal, "Failed to get server host")
	}

	if host == nil {
		return nil, nil, status.Error(codes.NotFound, "Server host not found")
	}

	if server.CanManage(host, user) {
		return server, user, nil
	}

	return nil, nil, status.Error(codes.PermissionDenied, "You are not a moderator of this server")
}
