package rpc

import (
	"context"
	"encoding/json"
	"time"

	"github.com/ArmchairDevelopers/Kyber/API/api/v1/pbapi"
	"github.com/ArmchairDevelopers/Kyber/API/api/v1/pbcommon"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/db"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/logger"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/models"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/mq"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/util"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/ws"
	"go.uber.org/zap"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/encoding/protojson"
)

type PartyService struct {
	store    *db.Store
	mq       mq.Client
	partyPub *mq.PartyEventPublisher
	sessions *ws.SessionManager
	pbapi.UnimplementedPartyServer
}

func NewPartyServer(store *db.Store, mqClient mq.Client, partyPub *mq.PartyEventPublisher, sessionManager *ws.SessionManager) *PartyService {
	s := &PartyService{
		store:    store,
		mq:       mqClient,
		partyPub: partyPub,
		sessions: sessionManager,
	}

	go s.consumePartyEvents()

	return s
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
	}

	if len(remainingSessions) == 0 {
		if err = s.store.Parties.Delete(ctx, partyID); err != nil {
			logger.L().Error("Failed to delete empty party", zap.Error(err))
		}
	} else if len(remainingSessions) > 0 {
		memberIDs := make([]string, len(remainingSessions))
		for i, sess := range remainingSessions {
			memberIDs[i] = sess.UserID
		}

		s.partyPub.Publish(partyID, memberIDs, &pbapi.PartyEvent{
			Body: &pbapi.PartyEvent_MemberLeft{
				MemberLeft: &pbapi.MemberLeftEvent{
					UserId: user.ID,
				},
			},
		})
	}

	logger.L().Debug("User left party", zap.Uint64("party_id", partyID), zap.String("user_id", user.ID))

	return &pbcommon.Empty{}, nil
}

func (s *PartyService) InvitePlayer(ctx context.Context, req *pbapi.InvitePlayerRequest) (*pbcommon.Empty, error) {
	user := ctx.Value("user").(*models.UserModel)

	session, err := s.store.Sessions.GetByUserID(ctx, user.ID)
	if err != nil {
		logger.L().Error("Failed to get session", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get session")
	}

	var party *models.PartyModel
	if session != nil && session.PartyID != nil {
		party, err = s.store.Parties.GetByID(ctx, *session.PartyID)
		if err != nil {
			logger.L().Error("Failed to get party", zap.Error(err))
			return nil, status.Error(codes.Internal, "Failed to get party")
		}
	}

	if party == nil {
		party, err = s.createParty(ctx, *user)
		if err != nil {
			return nil, status.Error(codes.Internal, "Failed to create party")
		}
	}

	inviteeSession, err := s.store.Sessions.GetByUserID(ctx, req.UserId)
	if err != nil {
		logger.L().Error("Failed to check invitee session", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to check invitee session")
	}

	if inviteeSession != nil && inviteeSession.PartyID != nil {
		return nil, status.Error(codes.AlreadyExists, "Player is already in a party")
	}

	invites, err := s.store.PartyInvites.GetInvites(ctx, party.ID)
	if err != nil {
		logger.L().Error("Failed to check existing invite", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to check existing invite")
	}

	if s.getInvite(invites, req.GetUserId()) != nil {
		return nil, status.Error(codes.AlreadyExists, "Invite already sent to this player")
	}

	if len(invites) >= 10 {
		return nil, status.Error(codes.AlreadyExists, "Reached the maximum number of invites")
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

	s.partyPub.Publish(party.ID, []string{req.UserId}, &pbapi.PartyEvent{
		Body: &pbapi.PartyEvent_InviteReceived{
			InviteReceived: &pbapi.InviteReceivedEvent{
				PartyId:     party.ID,
				Inviter:     user.Proto(),
				InviteToken: invite.ID,
				ExpiresAt:   invite.ExpiresAt.Unix(),
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
		return nil, status.Error(codes.AlreadyExists, "You are already in a party")
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

	if err := s.store.Sessions.SetPartyID(ctx, user.ID, &party.ID); err != nil {
		logger.L().Error("Failed to set party ID on session", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to join party")
	}

	if err := s.store.PartyInvites.Delete(ctx, invite.ID); err != nil {
		logger.L().Error("Failed to delete party invite", zap.Error(err))
	}

	allMemberIDs := make([]string, 0, len(existingSessions)+1)
	for _, sess := range existingSessions {
		allMemberIDs = append(allMemberIDs, sess.UserID)
	}

	s.partyPub.Publish(party.ID, allMemberIDs, &pbapi.PartyEvent{
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

	s.partyPub.Publish(party.ID, allMemberIDs, &pbapi.PartyEvent{
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

	return &pbapi.GetPartyResponse{Party: party.Proto(sessions, mapped)}, nil
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

func (s *PartyService) consumePartyEvents() {
	q, err := s.mq.Channel.QueueDeclare("", false, true, true, false, nil)
	if err != nil {
		logger.L().Error("Failed to declare party events queue", zap.Error(err))
		return
	}

	err = s.mq.Channel.QueueBind(q.Name, "", "party_events", false, nil)
	if err != nil {
		logger.L().Error("Failed to bind party events queue", zap.Error(err))
		return
	}

	msgs, err := s.mq.Channel.Consume(q.Name, "", true, false, false, false, nil)
	if err != nil {
		logger.L().Error("Failed to consume party events", zap.Error(err))
		return
	}

	for msg := range msgs {
		var wire mq.PartyEventWire
		if err := json.Unmarshal(msg.Body, &wire); err != nil {
			logger.L().Error("Failed to unmarshal party event wire", zap.Error(err))
			continue
		}

		var event pbapi.PartyEvent
		if err := protojson.Unmarshal(wire.Event, &event); err != nil {
			logger.L().Error("Failed to unmarshal party event proto", zap.Error(err))
			continue
		}

		s.sessions.Send(wire.UserIDs, &pbapi.SessionEvent{
			Body: &pbapi.SessionEvent_PartyEvent{
				PartyEvent: &event,
			},
		})
	}
}

func (s *PartyService) getInvite(invites []*models.PartyInviteModel, inviteeID string) *models.PartyInviteModel {
	for _, invite := range invites {
		if invite.InviteeID == inviteeID {
			return invite
		}
	}

	return nil
}
