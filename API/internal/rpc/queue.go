package rpc

import (
	"context"
	"fmt"

	"github.com/ArmchairDevelopers/Kyber/API/api/v1/pbapi"
	"github.com/ArmchairDevelopers/Kyber/API/api/v1/pbcommon"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/db"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/logger"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/models"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/queue"
	"go.uber.org/zap"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

type QueueService struct {
	store  *db.Store
	queues *queue.Manager
	pbapi.UnimplementedServerQueueServer
}

func NewQueueServer(store *db.Store, queues *queue.Manager) *QueueService {
	return &QueueService{
		store:  store,
		queues: queues,
	}
}

func getJoinableServer(ctx context.Context, store *db.Store, user *models.UserModel, serverID, password string) (*models.ServerModel, error) {
	server, err := store.Servers.GetByID(ctx, serverID)
	if err != nil {
		logger.L().Error("Failed to get server", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get server")
	}

	if server == nil {
		return nil, status.Error(codes.NotFound, "Server not found")
	}

	punishment, err := store.Punishments.GetBanForServer(ctx, server.HostID, user.ID)
	if err != nil {
		logger.L().Error("Failed to check ban", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to check ban")
	}

	if punishment != nil {
		reason := fmt.Sprintf("You are banned from this server: %s", *punishment.Reason)
		return nil, status.Error(codes.PermissionDenied, reason)
	}

	if server.Password != nil && *server.Password != password {
		return nil, status.Error(codes.PermissionDenied, "Invalid password")
	}

	return server, nil
}

func (s *QueueService) JoinQueue(ctx context.Context, req *pbapi.JoinQueueRequest) (*pbapi.QueueStatus, error) {
	user := ctx.Value("user").(*models.UserModel)

	session, err := s.store.Sessions.GetByUserID(ctx, user.ID)
	if err != nil {
		logger.L().Error("Failed to get session", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get session")
	}

	var partyId *uint64
	if session != nil && session.PartyID != nil {
		party, err := s.store.Parties.GetByID(ctx, *session.PartyID)
		if err != nil {
			logger.L().Error("Failed to get party", zap.Error(err))
			return nil, status.Error(codes.Internal, "Failed to get party")
		}

		if party == nil {
			return nil, status.Error(codes.NotFound, "Party not found")
		}

		if party.LeaderID != user.ID {
			return nil, status.Error(codes.FailedPrecondition, "Only the party leader can queue for a server")
		}

		if party.JoinGameState == nil || party.JoinGameState.ServerID != req.GetServerId() {
			return nil, status.Error(codes.FailedPrecondition, "Party is not in the correct join game state")
		}

		activeInvites, err := s.store.PartyInvites.GetActiveInvitesByPartyID(ctx, *session.PartyID)
		if err != nil {
			logger.L().Error("Failed to get party invites", zap.Error(err))
			return nil, status.Error(codes.Internal, "Failed to get party invites")
		}

		if len(activeInvites) > 0 {
			return nil, status.Error(codes.FailedPrecondition, "All party invites must be accepted or declined before joining a queue")
		}

		partyId = session.PartyID
	}

	server, err := getJoinableServer(ctx, s.store, user, req.GetServerId(), req.GetPassword())
	if err != nil {
		return nil, err
	}

	var existing *models.QueueEntryModel
	if partyId != nil {
		existing, err = s.store.Queues.GetByPartyID(ctx, *partyId)
	} else {
		existing, err = s.store.Queues.GetByUserID(ctx, user.ID)
	}

	if err != nil {
		logger.L().Error("Failed to get queue entry", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get queue entry")
	}

	if existing != nil {
		if existing.ServerID == server.ID {
			return s.queues.Status(ctx, existing), nil
		}

		s.queues.RemoveEntry(ctx, existing, pbapi.QueueRemovedReason_QUEUE_REMOVED_LEFT)
	}

	shouldQueue, err := s.queues.ShouldQueue(ctx, server)
	if err != nil {
		logger.L().Error("Failed to check queue requirement", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to check queue requirement")
	}

	// TODO: maybe not hard-error here?
	// if the server is not full, we could automatically create a new join token or let the launcher handle this by then trying to create a join token when receiving this error
	// or just merge it with the createJoinToken request
	if !shouldQueue {
		return nil, status.Error(codes.FailedPrecondition, "Server is not full")
	}

	entry, err := s.queues.Enqueue(ctx, server, partyId, &user.ID)
	if err != nil {
		logger.L().Error("Failed to create queue entry", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to join queue")
	}

	logger.L().Info("User joined server queue", zap.String("user_id", user.ID), zap.String("server_id", server.ID))

	s.queues.Advance(ctx, server.ID)

	current, err := s.store.Queues.GetByID(ctx, entry.ID)
	if err != nil || current == nil {
		current = entry
	}

	return s.queues.Status(ctx, current), nil
}

func (s *QueueService) LeaveQueue(ctx context.Context, _ *pbcommon.Empty) (*pbcommon.Empty, error) {
	user := ctx.Value("user").(*models.UserModel)

	entry, err := s.store.Queues.GetByUserID(ctx, user.ID)
	if err != nil {
		logger.L().Error("Failed to get queue entry", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get queue entry")
	}

	if entry == nil {
		return nil, status.Error(codes.NotFound, "You are not in a queue")
	}

	s.queues.RemoveEntry(ctx, entry, pbapi.QueueRemovedReason_QUEUE_REMOVED_LEFT)

	logger.L().Info("User left server queue", zap.String("user_id", user.ID), zap.String("server_id", entry.ServerID))

	return &pbcommon.Empty{}, nil
}

func (s *QueueService) GetQueueStatus(ctx context.Context, _ *pbcommon.Empty) (*pbapi.GetQueueStatusResponse, error) {
	user := ctx.Value("user").(*models.UserModel)

	session, err := s.store.Sessions.GetByUserID(ctx, user.ID)
	if err != nil {
		logger.L().Error("Failed to get session", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get session")
	}

	var entry *models.QueueEntryModel
	if session != nil && session.PartyID != nil {
		entry, err = s.store.Queues.GetByPartyID(ctx, *session.PartyID)
	} else {
		entry, err = s.store.Queues.GetByUserID(ctx, user.ID)
	}

	if err != nil {
		logger.L().Error("Failed to get queue entry", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get queue entry")
	}

	if entry == nil {
		return &pbapi.GetQueueStatusResponse{}, nil
	}

	return &pbapi.GetQueueStatusResponse{Status: s.queues.Status(ctx, entry)}, nil
}
