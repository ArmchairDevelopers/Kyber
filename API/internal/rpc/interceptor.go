package rpc

import (
	"context"
	"fmt"
	"strings"

	"github.com/ArmchairDevelopers/Kyber/API/pkg/db"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/logger"
	"go.uber.org/zap"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
)

type AuthHandler struct {
	store *db.Store
}

func NewAuthHandler(store *db.Store) *AuthHandler {
	return &AuthHandler{
		store: store,
	}
}

func (a *AuthHandler) NewAuthInterceptor() grpc.UnaryServerInterceptor {
	return func(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (resp any, err error) {
		service := strings.Split(info.FullMethod, "/")[1]
		if (!authMethods[fmt.Sprintf("/%s", service)] && !authMethods[info.FullMethod]) && (!optionalAuthMethods[info.FullMethod] && !optionalAuthMethods[fmt.Sprintf("/%s", service)]) {
			return handler(ctx, req)
		}

		md, ok := metadata.FromIncomingContext(ctx)
		if !ok {
			return nil, status.Error(codes.Unauthenticated, "missing metadata")
		}

		tokens := md.Get("authorization")
		if len(tokens) == 0 {
			if optionalAuthMethods[info.FullMethod] {
				return handler(ctx, req)
			}

			return nil, status.Error(codes.Unauthenticated, "missing token")
		}

		token := tokens[0]

		user, err := a.store.Users.GetByToken(ctx, token)
		if err != nil {
			logger.L().Error("Failed to get user by token", zap.Error(err))
			return nil, status.Error(codes.Internal, "Failed to get user by token")
		}

		if user == nil {
			return nil, status.Error(codes.Unauthenticated, "Invalid token")
		}

		ctx = context.WithValue(ctx, "user", user)

		return handler(ctx, req)
	}
}

var optionalAuthMethods = map[string]bool{
	"/kyber_api.Launcher/DownloadUrl": true,
}

var authMethods = map[string]bool{
	"/kyber_api.Authentication/UnlinkPatreonAccount": true,
	"/kyber_api.Authentication/UnlinkDiscordAccount": true,
	"/kyber_api.Authentication/Verify":               true,
	"/kyber_api.ServerBrowser/UploadModImages":       true,
	"/kyber_api.ClientServer/CreateJoinToken":        true,
	"/kyber_api.ServerBrowser/CanJoinServer":         true,
	"/kyber_api.ServerBrowser/UpdateServer":          true,
	"/kyber_api.ServerBrowser/RegisterServer":        true,
	"/kyber_api.ReportService/ListReports":           true,
	"/kyber_api.ReportService/GetUserReports":        true,
	"/kyber_api.ReportService/UpdateStatus":          true,
	"/kyber_api.ReportService/ApproveReports":        true,
	"/kyber_api.ReportService/RejectReport":          true,
	"/kyber_api.Statistics/UpdateStats":              true,
	"/kyber_api.Launcher/UploadMod":                  true,
	"/kyber_api.ServerManagement":                    true,
	"/kyber_api.ReportService":                       true,
	"/kyber_api.Party":                               true,
	"/kyber_api.Voip":                                true,
}
