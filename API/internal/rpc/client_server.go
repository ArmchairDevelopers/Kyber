package rpc

import (
	"context"
	"fmt"
	"time"

	"github.com/ArmchairDevelopers/Kyber/API/api/v1/pbapi"
	"github.com/ArmchairDevelopers/Kyber/API/api/v1/pbcommon"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/db"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/jwts"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/logger"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/models"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/util"
	"github.com/golang-jwt/jwt/v5"
	"go.mongodb.org/mongo-driver/bson"
	"go.uber.org/zap"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

type EventBlacklistConfig struct {
	Events []string `yaml:"events"`
}

type ClientServer struct {
	store             *db.Store
	jwt               *jwts.Service
	blacklistedEvents []string
	pbapi.UnimplementedClientServerServer
}

func NewClientServer(store *db.Store, jwt *jwts.Service) *ClientServer {
	config := &EventBlacklistConfig{}
	err := util.LoadConfig("event-blacklist.yaml", config)
	if err != nil {
		panic(err)
	}

	return &ClientServer{
		store:             store,
		blacklistedEvents: config.Events,
		jwt:               jwt,
	}
}

func (s *ClientServer) GetBlacklist(context.Context, *pbcommon.Empty) (*pbapi.EventSyncBlacklistResponse, error) {
	return &pbapi.EventSyncBlacklistResponse{
		BlacklistedEvents: s.blacklistedEvents,
	}, nil
}

func (s *ClientServer) CreateJoinToken(ctx context.Context, req *pbapi.JoinTokenRequest) (*pbapi.JoinTokenResponse, error) {
	user := ctx.Value("user").(*models.UserModel)

	server, err := s.store.Servers.GetByID(ctx, req.GetServer())
	if err != nil {
		logger.L().Error(err.Error())
		return nil, status.Error(codes.Internal, "Failed to get server")
	}

	if server == nil {
		return nil, status.Error(codes.NotFound, "Server not found")
	}

	punishment, err := s.isBanned(ctx, user.ID, server.HostID)
	if err != nil {
		return nil, err
	}

	if punishment != nil {
		reason := fmt.Sprintf("You are banned from this server: %s", *punishment.Reason)
		return nil, status.Error(codes.PermissionDenied, reason)
	}

	existingTokens, err := s.store.JoinTokens.GetByUserID(ctx, user.ID)
	if err != nil {
		logger.L().Error(err.Error())
		return nil, status.Error(codes.Internal, "Failed to get existing join tokens")
	}

	if len(existingTokens) > 0 {
		for _, token := range existingTokens {
			err := s.store.JoinTokens.DeleteByToken(ctx, token.ID)
			if err != nil {
				logger.L().Error(err.Error())
				return nil, status.Error(codes.Internal, "Failed to delete existing join tokens")
			}
		}
	}

	host, err := s.store.Users.GetByID(ctx, server.HostID)
	if err != nil {
		logger.L().Error("Failed to get server host", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get server host")
	}

	if host == nil {
		return nil, status.Error(codes.NotFound, "Server host not found")
	}

	isModerator := server.CanManage(host, user) || user.Entitled(models.EntitlementAdmin)
	isFull := server.PlayerCount >= server.MaxPlayerCount
	if !isModerator && !user.Entitled(models.EntitlementBypassPlayerLimit) && isFull {
		return nil, status.Error(codes.ResourceExhausted, "Server is full")
	}

	if server.Password != nil && !isModerator && *server.Password != req.Password {
		return nil, status.Error(codes.PermissionDenied, "Invalid password")
	}

	jwtToken := &models.ServerJWT{
		UserID:   user.ID,
		ServerID: server.ID,
		RegisteredClaims: jwt.RegisteredClaims{
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(15 * time.Minute)),
		},
	}

	token, err := s.jwt.SignToken(jwtToken)
	if err != nil {
		logger.L().Error(err.Error())
		return nil, status.Error(codes.Internal, "Failed to sign join token")
	}

	joinToken := &models.JoinTokenModel{
		ID:      util.GenerateToken(),
		Token:   token,
		User:    user.ID,
		Server:  server.ID,
		Created: time.Now(),
	}

	err = s.store.JoinTokens.Create(ctx, joinToken)
	if err != nil {
		logger.L().Error(err.Error())
		return nil, status.Error(codes.Internal, "Failed to create join token")
	}

	logger.L().Info(fmt.Sprintf("Created join token for user (id: %s, name: %s) on server (id: %s, name: %s)", user.ID, user.Name, server.ID, server.Name))
	return &pbapi.JoinTokenResponse{
		Token: token,
	}, nil
}

func (s *ClientServer) isBanned(ctx context.Context, userID string, hostID string) (*models.PunishmentModel, error) {
	punishment, err := s.store.Punishments.GetBanForServer(ctx, hostID, userID)
	if err != nil {
		logger.L().Error(err.Error())
		return nil, status.Error(codes.Internal, "Failed to get punishment")
	}

	return punishment, nil
}

func (s *ClientServer) ConsumeJoinToken(ctx context.Context, req *pbapi.ConsumeJoinTokenRequest) (*pbapi.ConsumeJoinTokenResponse, error) {
	tokenModel, err := s.store.JoinTokens.GetByToken(ctx, req.GetToken())
	if err != nil {
		logger.L().Error(err.Error())
		return nil, status.Error(codes.Internal, "Failed to get join token")
	}

	if tokenModel == nil {
		logger.L().Error("Join token not found", zap.String("token", req.GetToken()))
		return nil, status.Error(codes.NotFound, "Join token not found")
	}

	user, err := s.store.Users.GetByID(ctx, tokenModel.User)
	if err != nil {
		logger.L().Error(err.Error())
		return nil, status.Error(codes.Unauthenticated, "Failed to get user")
	}

	if user == nil {
		return nil, status.Error(codes.Unauthenticated, "User not found")
	}

	globalBan, err := s.store.Punishments.GetGlobalBan(ctx, user.ID)
	if err != nil {
		logger.L().Error(err.Error())
		return nil, status.Error(codes.Internal, "Failed to get global ban")
	}

	if globalBan != nil {
		return nil, status.Error(codes.PermissionDenied, "User is globally banned")
	}

	server, err := s.store.Servers.GetByID(ctx, tokenModel.Server)
	if err != nil {
		logger.L().Error(err.Error())
		return nil, status.Error(codes.Internal, "Failed to get server")
	}

	if server == nil {
		err := s.store.JoinTokens.DeleteByToken(ctx, tokenModel.ID)
		if err != nil {
			logger.L().Error(err.Error())
			return nil, status.Error(codes.Internal, "Failed to delete join token")
		}

		return nil, status.Error(codes.NotFound, "Server not found")
	}

	if server.ID != req.GetServer() {
		return nil, status.Error(codes.PermissionDenied, "The given join token was created for use on a different server")
	}

	punishment, err := s.store.Punishments.GetBanForServer(ctx, server.HostID, user.ID)
	if err != nil {
		logger.L().Error(err.Error())
		return nil, status.Error(codes.Internal, "Failed to get punishment")
	}

	if punishment != nil {
		return nil, status.Error(codes.PermissionDenied, "User is banned from this server")
	}

	err = s.store.JoinTokens.DeleteByToken(ctx, tokenModel.ID)
	if err != nil {
		logger.L().Error(err.Error())
		return nil, status.Error(codes.Internal, "Failed to delete join token")
	}

	err = s.store.Users.Update(ctx, user.ID, bson.M{"$inc": bson.M{"metric_data.servers_joined": 1}})
	if err != nil {
		logger.L().Error(err.Error())
		return nil, status.Error(codes.Internal, "Failed to update user")
	}

	logger.L().Info(fmt.Sprintf("Consumed join token for user (id: %s) on server (id: %s)", user.ID, server.ID))
	return &pbapi.ConsumeJoinTokenResponse{
		Id:   user.ID,
		Name: user.Name,
	}, nil
}
