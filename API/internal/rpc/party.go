package rpc

import (
	"context"
	"time"

	"github.com/ArmchairDevelopers/Kyber/API/api/v1/pbapi"
	"github.com/ArmchairDevelopers/Kyber/API/api/v1/pbcommon"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/db"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/logger"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/models"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/mq"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/queue"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/util"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/ws"
	"go.mongodb.org/mongo-driver/bson"
	"go.uber.org/zap"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

const maxPartySize = 20

type PartyService struct {
	store    *db.Store
	partyPub *mq.PartyEventPublisher
	sessions *ws.SessionManager
	queues   *queue.Manager
	pbapi.UnimplementedPartyServer
}

func NewPartyServer(store *db.Store, partyPub *mq.PartyEventPublisher, sessionManager *ws.SessionManager, queues *queue.Manager) *PartyService {
	return &PartyService{
		store:    store,
		partyPub: partyPub,
		sessions: sessionManager,
		queues:   queues,
	}
}

func (s *PartyService) CancelJoinGame(ctx context.Context, _ *pbcommon.Empty) (*pbcommon.Empty, error) {
	user := ctx.Value("user").(*models.UserModel)

	session, err := s.store.Sessions.GetByUserID(ctx, user.ID)
	if err != nil {
		logger.L().Error("Failed to get session", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get session")
	}

	if session == nil || session.PartyID == nil {
		return nil, status.Error(codes.NotFound, "You are not in a party")
	}

	partyID := *session.PartyID
	party, err := s.store.Parties.GetByID(ctx, partyID)
	if err != nil {
		logger.L().Error("Failed to get party", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get party")
	}

	if party == nil {
		return nil, status.Error(codes.NotFound, "Party not found")
	}

	if party.LeaderID != user.ID {
		return nil, status.Error(codes.PermissionDenied, "Only the party leader can cancel joining a game")
	}

	if party.JoinGameState == nil {
		return nil, status.Error(codes.InvalidArgument, "Not currently joining a game")
	}

	if err := s.store.Parties.Update(ctx, partyID, bson.M{"$unset": bson.M{"join_game_state": ""}}); err != nil {
		logger.L().Error("Failed to clear join game state", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to cancel joining game")
	}

	s.queues.RemoveByPartyID(ctx, partyID, pbapi.QueueRemovedReason_QUEUE_REMOVED_LEFT)

	sessions, err := s.store.Sessions.GetByPartyID(ctx, partyID)
	if err != nil {
		logger.L().Error("Failed to get party sessions", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to cancel joining game")
	}

	userIDs := make([]string, 0, len(sessions))
	for _, s := range sessions {
		userIDs = append(userIDs, s.UserID)
	}

	s.partyPub.Publish(userIDs, &pbapi.PartyEvent{
		Body: &pbapi.PartyEvent_JoinGameCancelled{
			JoinGameCancelled: &pbapi.JoinGameCancelledEvent{},
		},
	})

	logger.L().Debug("Cancelled joining game", zap.Uint64("party_id", partyID), zap.String("user_id", user.ID))

	return &pbcommon.Empty{}, nil
}

func (s *PartyService) LeaveParty(ctx context.Context, _ *pbcommon.Empty) (*pbcommon.Empty, error) {
	user := ctx.Value("user").(*models.UserModel)

	session, err := s.store.Sessions.GetByUserID(ctx, user.ID)
	if err != nil {
		logger.L().Error("Failed to get session", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get session")
	}

	if session == nil || session.PartyID == nil {
		return nil, status.Error(codes.NotFound, "You are not in a party")
	}

	partyID := *session.PartyID

	if err := s.store.Sessions.SetPartyID(ctx, user.ID, nil); err != nil {
		logger.L().Error("Failed to clear party ID", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to leave party")
	}

	remainingSessions, err := s.store.Sessions.GetByPartyID(ctx, partyID)
	if err != nil {
		logger.L().Error("Failed to get remaining sessions", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to leave party")
	}

	if len(remainingSessions) < 2 {
		if err = s.store.Parties.Delete(ctx, partyID); err != nil {
			logger.L().Error("Failed to delete empty party", zap.Error(err))
		}

		s.queues.RemoveByPartyID(ctx, partyID, pbapi.QueueRemovedReason_QUEUE_REMOVED_LEFT)

		for _, sess := range remainingSessions {
			if err := s.store.Sessions.SetPartyID(ctx, sess.UserID, nil); err != nil {
				logger.L().Error("Failed to clear party ID on remaining session", zap.Error(err))
			}
		}

		if len(remainingSessions) > 0 {
			memberIDs := []string{remainingSessions[0].UserID}
			s.partyPub.Publish(memberIDs, &pbapi.PartyEvent{
				Body: &pbapi.PartyEvent_MemberLeft{
					MemberLeft: &pbapi.MemberLeftEvent{
						UserId: user.ID,
					},
				},
			})
		}
	} else {
		memberIDs := make([]string, len(remainingSessions))
		for i, sess := range remainingSessions {
			memberIDs[i] = sess.UserID
		}

		s.partyPub.Publish(memberIDs, &pbapi.PartyEvent{
			Body: &pbapi.PartyEvent_MemberLeft{
				MemberLeft: &pbapi.MemberLeftEvent{
					UserId: user.ID,
				},
			},
		})

		if err := s.store.Parties.RemoveMemberStatus(ctx, partyID, user.ID); err != nil {
			logger.L().Error("Failed to prune member join status", zap.Error(err))
		}

		party, err := s.store.Parties.GetByID(ctx, partyID)
		if err != nil {
			logger.L().Error("Failed to get party after leave", zap.Error(err))
		} else if party != nil && party.LeaderID == user.ID {
			if party.JoinGameState != nil {
				if err := s.store.Parties.Update(ctx, partyID, bson.M{"$unset": bson.M{"join_game_state": ""}}); err != nil {
					logger.L().Error("Failed to clear join game state", zap.Error(err))
				}

				s.queues.RemoveByPartyID(ctx, partyID, pbapi.QueueRemovedReason_QUEUE_REMOVED_LEFT)

				s.partyPub.Publish(memberIDs, &pbapi.PartyEvent{
					Body: &pbapi.PartyEvent_JoinGameCancelled{
						JoinGameCancelled: &pbapi.JoinGameCancelledEvent{},
					},
				})
			}

			newLeaderID := remainingSessions[0].UserID
			if err := s.store.Parties.Update(ctx, partyID, bson.M{"$set": bson.M{"leader_id": newLeaderID}}); err != nil {
				logger.L().Error("Failed to update party leader", zap.Error(err))
			}

			s.partyPub.Publish(memberIDs, &pbapi.PartyEvent{
				Body: &pbapi.PartyEvent_NewLeader{
					NewLeader: &pbapi.NewLeaderEvent{
						NewLeaderId: newLeaderID,
					},
				},
			})
		}
	}

	logger.L().Debug("User left party", zap.Uint64("party_id", partyID), zap.String("user_id", user.ID))

	return &pbcommon.Empty{}, nil
}

func (s *PartyService) InvitePlayer(ctx context.Context, req *pbapi.InvitePlayerRequest) (*pbcommon.Empty, error) {
	user := ctx.Value("user").(*models.UserModel)

	if user.ID == req.UserId {
		return nil, status.Error(codes.InvalidArgument, "You cannot invite yourself to a party")
	}

	session, err := s.store.Sessions.GetByUserID(ctx, user.ID)
	if err != nil {
		logger.L().Error("Failed to get session", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get session")
	}

	if session == nil {
		return nil, status.Error(codes.FailedPrecondition, "You have no active session")
	}

	inviteeSession, err := s.store.Sessions.GetByUserID(ctx, req.UserId)
	if err != nil {
		logger.L().Error("Failed to check invitee session", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to check invitee session")
	}

	if inviteeSession == nil {
		return &pbcommon.Empty{}, nil
	}

	var party *models.PartyModel
	if session.PartyID != nil {
		party, err = s.store.Parties.GetByID(ctx, *session.PartyID)
		if err != nil {
			logger.L().Error("Failed to get party", zap.Error(err))
			return nil, status.Error(codes.Internal, "Failed to get party")
		}
	}

	isInQueue := false

	if party == nil {
		queueEntry, err := s.store.Queues.GetByUserID(ctx, user.ID)
		if err != nil {
			logger.L().Error("Failed to get queue", zap.Error(err))
			return nil, status.Error(codes.Internal, "Failed to get queue")
		}

		isInQueue = queueEntry != nil

		if !isInQueue {
			party, err = s.createParty(ctx, *user)
			if err != nil {
				return nil, status.Error(codes.Internal, "Failed to create party")
			}
		}
	} else {
		queueEntry, err := s.store.Queues.GetByPartyID(ctx, party.ID)
		if err != nil {
			logger.L().Error("Failed to get queue", zap.Error(err))
			return nil, status.Error(codes.Internal, "Failed to get queue")
		}

		isInQueue = queueEntry != nil
	}

	if isInQueue {
		return nil, status.Error(codes.FailedPrecondition, "To invite a player to a party, you must leave the queue")
	}

	if inviteeSession.PartyID != nil {
		if *inviteeSession.PartyID == party.ID {
			return nil, status.Error(codes.AlreadyExists, "Player is already in your party")
		}

		inviteePartyMembers, err := s.store.Sessions.GetByPartyID(ctx, *inviteeSession.PartyID)
		if err != nil {
			logger.L().Error("Failed to check invitee party sessions", zap.Error(err))
			return nil, status.Error(codes.Internal, "Failed to check invitee party sessions")
		}

		if len(inviteePartyMembers) > 1 {
			return nil, status.Error(codes.FailedPrecondition, "Player is already in a party")
		}

		if len(inviteePartyMembers) == 1 && inviteePartyMembers[0].UserID != inviteeSession.UserID {
			return nil, status.Error(codes.FailedPrecondition, "Player is already in a party")
		}

		openInvites, err := s.store.PartyInvites.GetInvites(ctx, *inviteeSession.PartyID)
		if err != nil {
			logger.L().Error("Failed to check invitee party invites", zap.Error(err))
			return nil, status.Error(codes.Internal, "Failed to check invitee party invites")
		}

		if len(openInvites) > 0 {
			return nil, status.Error(codes.FailedPrecondition, "Player is already in a party")
		}

		// TODO: maybe do a transaction here so that the sessions party id gets cleared if the party delete fails
		inviteePartyID := *inviteeSession.PartyID
		if err := s.store.Parties.Delete(ctx, inviteePartyID); err != nil {
			logger.L().Error("Failed to delete invitee's empty party", zap.Error(err))
			return nil, status.Error(codes.Internal, "Failed to check invitee party")
		}

		if err := s.store.Sessions.SetPartyID(ctx, inviteeSession.UserID, nil); err != nil {
			logger.L().Error("Failed to clear invitee's party ID", zap.Error(err))
			return nil, status.Error(codes.Internal, "Failed to check invitee party")
		}

		s.queues.RemoveByPartyID(ctx, inviteePartyID, pbapi.QueueRemovedReason_QUEUE_REMOVED_LEFT)

		s.partyPub.Publish([]string{inviteeSession.UserID}, &pbapi.PartyEvent{
			Body: &pbapi.PartyEvent_MemberLeft{
				MemberLeft: &pbapi.MemberLeftEvent{
					UserId: inviteeSession.UserID,
				},
			},
		})
	}

	invites, err := s.store.PartyInvites.GetInvites(ctx, party.ID)
	if err != nil {
		logger.L().Error("Failed to check existing invite", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to check existing invite")
	}

	now := time.Now()
	activeInvites := make([]*models.PartyInviteModel, 0, len(invites))
	for _, inv := range invites {
		if now.Before(inv.ExpiresAt) {
			activeInvites = append(activeInvites, inv)
			continue
		}

		if err := s.store.PartyInvites.Delete(ctx, inv.ID); err != nil {
			logger.L().Error("Failed to delete expired party invite", zap.Error(err))
		}
	}

	if s.getInvite(activeInvites, req.GetUserId()) != nil {
		return nil, status.Error(codes.AlreadyExists, "Invite already sent to this player")
	}

	currentMembers, err := s.store.Sessions.CountByPartyID(ctx, party.ID)
	if err != nil {
		logger.L().Error("Failed to count party members", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to count party members")
	}

	if int(currentMembers)+len(activeInvites)+1 > maxPartySize {
		return nil, status.Error(codes.ResourceExhausted, "Party is full")
	}

	invitee, err := s.store.Users.GetByID(ctx, req.UserId)
	if err != nil {
		logger.L().Error("Failed to get invitee", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get invitee")
	}

	if invitee == nil {
		return nil, status.Error(codes.NotFound, "Player not found")
	}

	invite := models.PartyInviteModel{
		ID:        util.GenerateToken(),
		InviterID: user.ID,
		InviteeID: req.UserId,
		PartyID:   party.ID,
		ExpiresAt: time.Now().Add(1 * time.Minute),
		CreatedAt: time.Now(),
	}

	if err := s.store.PartyInvites.Create(ctx, &invite); err != nil {
		logger.L().Error("Failed to add invite to party", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to add invite to party")
	}

	partyMembers, err := s.store.Sessions.GetByPartyID(ctx, party.ID)
	if err != nil {
		logger.L().Error("Failed to get party members", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get party members")
	}

	s.partyPub.Publish([]string{req.UserId}, &pbapi.PartyEvent{
		Body: &pbapi.PartyEvent_InviteReceived{
			InviteReceived: &pbapi.InviteReceivedEvent{
				PartyId:     party.ID,
				Inviter:     user.Proto(),
				InviteToken: invite.ID,
				ExpiresAt:   invite.ExpiresAt.Unix(),
				PartySize:   uint32(len(partyMembers)),
			},
		},
	})

	logger.L().Debug("Sent party invite", zap.Uint64("party_id", party.ID), zap.String("inviter_id", user.ID), zap.String("invitee_id", req.UserId))

	return &pbcommon.Empty{}, nil
}

func (s *PartyService) AcceptInvite(ctx context.Context, req *pbapi.AcceptInviteRequest) (*pbcommon.Empty, error) {
	user := ctx.Value("user").(*models.UserModel)

	session, err := s.store.Sessions.GetByUserID(ctx, user.ID)
	if err != nil {
		logger.L().Error("Failed to get session", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get session")
	}

	if session != nil && session.PartyID != nil {
		existingParty, err := s.store.Parties.GetByID(ctx, *session.PartyID)
		if err != nil {
			logger.L().Error("Failed to get existing party", zap.Error(err))
			return nil, status.Error(codes.Internal, "Failed to get existing party")
		}

		if existingParty != nil {
			return nil, status.Error(codes.AlreadyExists, "You are already in a party")
		}

		if err := s.store.Sessions.SetPartyID(ctx, user.ID, nil); err != nil {
			logger.L().Error("Failed to clear orphaned party ID", zap.Error(err))
			return nil, status.Error(codes.Internal, "Failed to clear orphaned party ID")
		}
	}

	party, err := s.store.Parties.GetByID(ctx, req.PartyId)
	if err != nil {
		logger.L().Error("Failed to get party", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get party")
	}

	if party == nil {
		return nil, status.Error(codes.NotFound, "Party not found")
	}

	invite, err := s.store.PartyInvites.GetByInvitee(ctx, req.GetPartyId(), user.ID)
	if err != nil {
		logger.L().Error("Failed to get party invite", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get party invite")
	}

	if invite == nil {
		return nil, status.Error(codes.NotFound, "Invite not found")
	}

	if time.Now().After(invite.ExpiresAt) {
		if err = s.store.PartyInvites.Delete(ctx, invite.ID); err != nil {
			logger.L().Error("Failed to delete expired party invite", zap.Error(err))
		}
		return nil, status.Error(codes.DeadlineExceeded, "Invite has expired")
	}

	existingSessions, err := s.store.Sessions.GetByPartyID(ctx, party.ID)
	if err != nil {
		logger.L().Error("Failed to get party sessions", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get party sessions")
	}

	if len(existingSessions) >= maxPartySize {
		if err := s.store.PartyInvites.Delete(ctx, invite.ID); err != nil {
			logger.L().Error("Failed to delete invite for full party", zap.Error(err))
		}

		return nil, status.Error(codes.ResourceExhausted, "Party is full")
	}

	queueEntry, err := s.store.Queues.GetByUserID(ctx, user.ID)
	if err != nil {
		logger.L().Error("Failed to get queue entry", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get queue entry")
	}

	if queueEntry != nil {
		return nil, status.Error(codes.FailedPrecondition, "You can't join a party while in a queue")
	}

	partyQueueEntry, err := s.store.Queues.GetByPartyID(ctx, party.ID)
	if err != nil {
		logger.L().Error("Failed to get party queue entry", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get party queue entry")
	}

	if partyQueueEntry != nil {
		return nil, status.Error(codes.FailedPrecondition, "You can't join a party that is in a queue")
	}

	if err := s.store.Sessions.SetPartyID(ctx, user.ID, &party.ID); err != nil {
		logger.L().Error("Failed to set party ID on session", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to join party")
	}

	currentSessions, err := s.store.Sessions.GetByPartyID(ctx, party.ID)
	if err == nil && len(currentSessions) > maxPartySize {
		if err := s.store.Sessions.SetPartyID(ctx, user.ID, nil); err != nil {
			logger.L().Error("Failed to back out of full party", zap.Error(err))
		}

		if err := s.store.PartyInvites.Delete(ctx, invite.ID); err != nil {
			logger.L().Error("Failed to delete invite for full party", zap.Error(err))
		}

		return nil, status.Error(codes.ResourceExhausted, "Party is full")
	}

	if err := s.store.PartyInvites.Delete(ctx, invite.ID); err != nil {
		logger.L().Error("Failed to delete party invite", zap.Error(err))
	}

	s.queues.RemoveByUserID(ctx, user.ID, pbapi.QueueRemovedReason_QUEUE_REMOVED_LEFT)

	allMemberIDs := make([]string, 0, len(existingSessions)+1)
	for _, sess := range existingSessions {
		allMemberIDs = append(allMemberIDs, sess.UserID)
	}
	allMemberIDs = append(allMemberIDs, user.ID)

	s.partyPub.Publish(allMemberIDs, &pbapi.PartyEvent{
		Body: &pbapi.PartyEvent_MemberJoined{
			MemberJoined: &pbapi.MemberJoinedEvent{
				User: user.Proto(),
			},
		},
	})

	logger.L().Info("User accepted party invite", zap.Uint64("party_id", party.ID), zap.String("user_id", user.ID))

	return &pbcommon.Empty{}, nil
}

func (s *PartyService) DeclineInvite(ctx context.Context, req *pbapi.DeclineInviteRequest) (*pbcommon.Empty, error) {
	user := ctx.Value("user").(*models.UserModel)

	party, err := s.store.Parties.GetByID(ctx, req.PartyId)
	if err != nil {
		logger.L().Error("Failed to get party invite", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get party invite")
	}

	if party == nil {
		return nil, status.Error(codes.NotFound, "Party invite not found")
	}

	invite, err := s.store.PartyInvites.GetByInvitee(ctx, req.GetPartyId(), user.ID)
	if err != nil {
		logger.L().Error("Failed to get party invite", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get party invite")
	}

	if invite == nil {
		return nil, status.Error(codes.NotFound, "Invite not found")
	}

	if err := s.store.PartyInvites.Delete(ctx, invite.ID); err != nil {
		logger.L().Error("Failed to delete party invite", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to delete party invite")
	}

	sessions, err := s.store.Sessions.GetByPartyID(ctx, party.ID)
	if err != nil {
		logger.L().Error("Failed to get party sessions", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get party sessions")
	}

	allMemberIDs := make([]string, len(sessions))
	for i, sess := range sessions {
		allMemberIDs[i] = sess.UserID
	}

	s.partyPub.Publish(allMemberIDs, &pbapi.PartyEvent{
		Body: &pbapi.PartyEvent_InviteDeclined{
			InviteDeclined: &pbapi.InviteDeclinedEvent{
				User: user.Proto(),
			},
		},
	})

	logger.L().Info("User declined party invite", zap.Uint64("party_id", party.ID), zap.String("user_id", user.ID))

	return &pbcommon.Empty{}, nil
}

func (s *PartyService) GetParty(ctx context.Context, _ *pbcommon.Empty) (*pbapi.GetPartyResponse, error) {
	user := ctx.Value("user").(*models.UserModel)

	session, err := s.store.Sessions.GetByUserID(ctx, user.ID)
	if err != nil {
		logger.L().Error("Failed to get session", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get session")
	}

	if session == nil || session.PartyID == nil {
		return &pbapi.GetPartyResponse{}, nil
	}

	party, err := s.store.Parties.GetByID(ctx, *session.PartyID)
	if err != nil {
		logger.L().Error("Failed to get party", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get party")
	}

	if party == nil {
		return &pbapi.GetPartyResponse{}, nil
	}

	sessions, err := s.store.Sessions.GetByPartyID(ctx, party.ID)
	if err != nil {
		logger.L().Error("Failed to get party sessions", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get party sessions")
	}

	memberIDs := make([]string, len(sessions))
	for i, sess := range sessions {
		memberIDs[i] = sess.UserID
	}

	users, err := s.store.Users.SearchByIDs(ctx, memberIDs)
	if err != nil {
		logger.L().Error("Failed to get member users", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get member users")
	}

	mapped := make(map[string]*models.UserModel)
	for _, u := range users {
		mapped[u.ID] = u
	}

	state := party.Proto(sessions, mapped)

	if state.JoinGameState != nil {
		entry, err := s.store.Queues.GetByPartyID(ctx, party.ID)
		if err != nil {
			logger.L().Error("Failed to get queue entry", zap.Error(err))
			return nil, status.Error(codes.Internal, "Failed to get queue entry")
		} else if entry != nil {
			state.JoinGameState.Queue = s.queues.Status(ctx, entry)
		}
	}

	return &pbapi.GetPartyResponse{Party: state}, nil
}

func (s *PartyService) StartJoinGame(ctx context.Context, req *pbapi.StartJoinGameRequest) (*pbcommon.Empty, error) {
	user := ctx.Value("user").(*models.UserModel)

	session, err := s.store.Sessions.GetByUserID(ctx, user.ID)
	if err != nil {
		logger.L().Error("Failed to get session", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get session")
	}

	if session == nil || session.PartyID == nil {
		return nil, status.Error(codes.NotFound, "You are not in a party")
	}

	party, err := s.store.Parties.GetByID(ctx, *session.PartyID)
	if err != nil {
		logger.L().Error("Failed to get party", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get party")
	}

	if party == nil {
		return nil, status.Error(codes.NotFound, "Party not found")
	}

	if party.LeaderID != user.ID {
		return nil, status.Error(codes.PermissionDenied, "Only the party leader can join a game")
	}

	server, err := getJoinableServer(ctx, s.store, user, req.GetServerId(), req.Password)
	if err != nil {
		return nil, err
	}

	sessions, err := s.store.Sessions.GetByPartyID(ctx, party.ID)
	if err != nil {
		logger.L().Error("Failed to get party sessions", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get party sessions")
	}

	memberIDs := make([]string, len(sessions))
	for i, sess := range sessions {
		memberIDs[i] = sess.UserID
	}

	existingEntry, err := s.store.Queues.GetByPartyID(ctx, party.ID)
	if err != nil {
		logger.L().Error("Failed to get queue entry", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to start join game")
	}

	openInvites, err := s.store.PartyInvites.GetActiveInvitesByPartyID(ctx, party.ID)
	if err != nil {
		logger.L().Error("Failed to get party invites", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to start join game")
	}

	if len(openInvites) > 0 {
		return nil, status.Error(codes.FailedPrecondition, "All invites must be accepted or declined before joining a game")
	}

	if existingEntry != nil && existingEntry.ServerID != server.ID {
		s.queues.RemoveEntry(ctx, existingEntry, pbapi.QueueRemovedReason_QUEUE_REMOVED_LEFT)
		existingEntry = nil
	}

	joinGameState := &models.PartyJoinGameState{
		ServerID:   server.ID,
		ServerName: server.Name,
		Mods:       server.Mods,
		Password:   req.Password,
	}

	queueEntry := existingEntry
	if queueEntry == nil {
		shouldQueue, err := s.queues.ShouldQueue(ctx, server)
		if err != nil {
			logger.L().Error("Failed to check queue requirement", zap.Error(err))
			return nil, status.Error(codes.Internal, "Failed to start join game")
		}

		if shouldQueue {
			queueEntry, err = s.queues.Enqueue(ctx, server, &party.ID, nil)
			if err != nil {
				logger.L().Error("Failed to create queue entry", zap.Error(err))
				return nil, status.Error(codes.Internal, "Failed to join server queue")
			}

			logger.L().Info("Party joined server queue", zap.Uint64("party_id", party.ID), zap.String("server_id", server.ID))
		}
	}

	if err := s.store.Parties.Update(ctx, party.ID, bson.M{"$set": bson.M{"join_game_state": joinGameState}}); err != nil {
		logger.L().Error("Failed to save join game state", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to start join game")
	}

	protoMods := make([]*pbcommon.ServerMod, len(server.Mods))
	for i, mod := range server.Mods {
		protoMods[i] = &pbcommon.ServerMod{
			Name:     mod.Name,
			Version:  mod.Version,
			Link:     mod.Link,
			FileSize: mod.FileSize,
		}
	}

	joinGameEvent := &pbapi.JoinGameEvent{
		ServerId:   server.ID,
		ServerName: server.Name,
		Mods:       protoMods,
		LeaderId:   user.ID,
	}

	if req.Password != "" {
		joinGameEvent.Password = &req.Password
	}

	if queueEntry != nil {
		joinGameEvent.Queue = s.queues.Status(ctx, queueEntry)
	}

	s.partyPub.Publish(memberIDs, &pbapi.PartyEvent{
		Body: &pbapi.PartyEvent_JoinGame{
			JoinGame: joinGameEvent,
		},
	})

	return &pbcommon.Empty{}, nil
}

func (s *PartyService) KickMember(ctx context.Context, req *pbapi.KickMemberRequest) (*pbcommon.Empty, error) {
	user := ctx.Value("user").(*models.UserModel)

	if req.UserId == user.ID {
		return nil, status.Error(codes.InvalidArgument, "You cannot kick yourself")
	}

	session, err := s.store.Sessions.GetByUserID(ctx, user.ID)
	if err != nil {
		logger.L().Error("Failed to get session", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get session")
	}

	if session == nil || session.PartyID == nil {
		return nil, status.Error(codes.NotFound, "You are not in a party")
	}

	partyID := *session.PartyID
	party, err := s.store.Parties.GetByID(ctx, partyID)
	if err != nil {
		logger.L().Error("Failed to get party", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get party")
	}

	if party == nil {
		return nil, status.Error(codes.NotFound, "Party not found")
	}

	if party.LeaderID != user.ID {
		return nil, status.Error(codes.PermissionDenied, "Only the party leader can kick members")
	}

	targetSession, err := s.store.Sessions.GetByUserID(ctx, req.UserId)
	if err != nil {
		logger.L().Error("Failed to get target session", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get target session")
	}

	if targetSession == nil || targetSession.PartyID == nil || *targetSession.PartyID != partyID {
		return nil, status.Error(codes.FailedPrecondition, "Player is not in your party")
	}

	if err := s.store.Sessions.SetPartyID(ctx, req.UserId, nil); err != nil {
		logger.L().Error("Failed to clear kicked member's party ID", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to kick member")
	}

	remainingSessions, err := s.store.Sessions.GetByPartyID(ctx, partyID)
	if err != nil {
		logger.L().Error("Failed to get remaining sessions", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to kick member")
	}

	memberIDs := make([]string, len(remainingSessions))
	for i, sess := range remainingSessions {
		memberIDs[i] = sess.UserID
	}

	s.partyPub.Publish([]string{req.UserId}, &pbapi.PartyEvent{
		Body: &pbapi.PartyEvent_Kicked{
			Kicked: &pbapi.KickedEvent{
				UserId: req.UserId,
			},
		},
	})

	if err := s.store.Parties.RemoveMemberStatus(ctx, partyID, req.UserId); err != nil {
		logger.L().Error("Failed to prune member join status", zap.Error(err))
	}

	if len(remainingSessions) < 2 {
		if err := s.store.Parties.Delete(ctx, partyID); err != nil {
			logger.L().Error("Failed to delete empty party", zap.Error(err))
		}

		s.queues.RemoveByPartyID(ctx, partyID, pbapi.QueueRemovedReason_QUEUE_REMOVED_LEFT)

		for _, sess := range remainingSessions {
			if err := s.store.Sessions.SetPartyID(ctx, sess.UserID, nil); err != nil {
				logger.L().Error("Failed to clear party ID on remaining session", zap.Error(err))
			}
		}
	}

	if len(memberIDs) > 0 {
		s.partyPub.Publish(memberIDs, &pbapi.PartyEvent{
			Body: &pbapi.PartyEvent_MemberLeft{
				MemberLeft: &pbapi.MemberLeftEvent{
					UserId: req.UserId,
				},
			},
		})
	}

	logger.L().Info("Kicked member", zap.Uint64("party_id", partyID), zap.String("user_id", req.UserId))

	return &pbcommon.Empty{}, nil
}

func (s *PartyService) TransferLeader(ctx context.Context, req *pbapi.TransferLeaderRequest) (*pbcommon.Empty, error) {
	user := ctx.Value("user").(*models.UserModel)

	if req.UserId == user.ID {
		return nil, status.Error(codes.InvalidArgument, "You are already the leader")
	}

	session, err := s.store.Sessions.GetByUserID(ctx, user.ID)
	if err != nil {
		logger.L().Error("Failed to get session", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get session")
	}

	if session == nil || session.PartyID == nil {
		return nil, status.Error(codes.NotFound, "You are not in a party")
	}

	partyID := *session.PartyID
	party, err := s.store.Parties.GetByID(ctx, partyID)
	if err != nil {
		logger.L().Error("Failed to get party", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get party")
	}

	if party == nil {
		return nil, status.Error(codes.NotFound, "Party not found")
	}

	if party.LeaderID != user.ID {
		return nil, status.Error(codes.PermissionDenied, "Only the party leader can transfer leadership")
	}

	targetSession, err := s.store.Sessions.GetByUserID(ctx, req.UserId)
	if err != nil {
		logger.L().Error("Failed to get target session", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get target session")
	}

	if targetSession == nil || targetSession.PartyID == nil || *targetSession.PartyID != partyID {
		return nil, status.Error(codes.FailedPrecondition, "Player is not in your party")
	}

	if err := s.store.Parties.Update(ctx, partyID, bson.M{"$set": bson.M{"leader_id": req.UserId}}); err != nil {
		logger.L().Error("Failed to transfer leader", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to transfer leader")
	}

	sessions, err := s.store.Sessions.GetByPartyID(ctx, partyID)
	if err != nil {
		logger.L().Error("Failed to get party sessions", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get party sessions")
	}

	memberIDs := make([]string, len(sessions))
	for i, sess := range sessions {
		memberIDs[i] = sess.UserID
	}

	s.partyPub.Publish(memberIDs, &pbapi.PartyEvent{
		Body: &pbapi.PartyEvent_NewLeader{
			NewLeader: &pbapi.NewLeaderEvent{
				NewLeaderId: req.UserId,
			},
		},
	})

	logger.L().Info("Transferred party leader", zap.Uint64("party_id", partyID), zap.String("from", user.ID), zap.String("to", req.UserId))

	return &pbcommon.Empty{}, nil
}

func (s *PartyService) createParty(ctx context.Context, user models.UserModel) (*models.PartyModel, error) {
	partyID, err := s.store.Parties.GetNextID(ctx)
	if err != nil {
		logger.L().Error("Failed to get next party ID", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to generate party ID")
	}

	party := &models.PartyModel{
		ID:        partyID,
		LeaderID:  user.ID,
		CreatedAt: time.Now(),
	}

	if err := s.store.Parties.Create(ctx, party); err != nil {
		logger.L().Error("Failed to create party", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to create party")
	}

	if err := s.store.Sessions.SetPartyID(ctx, user.ID, &partyID); err != nil {
		logger.L().Error("Failed to set party ID on session", zap.Error(err))
		if err := s.store.Parties.Delete(ctx, partyID); err != nil {
			logger.L().Error("Failed to delete party after session update failure", zap.Error(err))
		}
		return nil, status.Error(codes.Internal, "Failed to join party")
	}

	logger.L().Info("Created party", zap.Uint64("party_id", party.ID), zap.String("leader_id", user.ID))

	return party, nil
}

func (s *PartyService) getInvite(invites []*models.PartyInviteModel, inviteeID string) *models.PartyInviteModel {
	for _, invite := range invites {
		if invite.InviteeID == inviteeID {
			return invite
		}
	}

	return nil
}
