package rpc

import (
	"context"
	"encoding/json"
	"sync"
	"time"

	"github.com/ArmchairDevelopers/Kyber/API/api/v1/pbapi"
	"github.com/ArmchairDevelopers/Kyber/API/api/v1/pbcommon"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/db"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/logger"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/models"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/mq"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/util"
	amqp "github.com/rabbitmq/amqp091-go"
	"go.mongodb.org/mongo-driver/bson"
	"go.uber.org/zap"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/encoding/protojson"
)

type partyEventWire struct {
	PartyID uint64          `json:"party_id"`
	UserIDs []string        `json:"user_ids"`
	Event   json.RawMessage `json:"event"`
}

type PartyEventMessage struct {
	PartyID uint64            `json:"party_id"`
	UserIDs []string          `json:"user_ids"`
	Event   *pbapi.PartyEvent `json:"event"`
}

type PartyService struct {
	store       *db.Store
	mq          mq.Client
	mu          sync.RWMutex
	subs        map[string]chan *pbapi.PartyEvent
	lastSubTime map[string]time.Time
	pbapi.UnimplementedPartyServer
}

func NewPartyServer(store *db.Store, mqClient mq.Client) *PartyService {
	s := &PartyService{
		store:       store,
		mq:          mqClient,
		subs:        make(map[string]chan *pbapi.PartyEvent),
		lastSubTime: make(map[string]time.Time),
	}

	go s.consumePartyEvents()
	go s.consumePresenceEvents()
	go s.heartbeatPresence()
	go s.cleanupOrphanedMembers()
	go s.cleanupDisconnectedPlayers()

	return s
}

func (s *PartyService) Subscribe(_ *pbcommon.Empty, stream pbapi.Party_SubscribeServer) error {
	user := stream.Context().Value("user").(*models.UserModel)

	ch := make(chan *pbapi.PartyEvent, 10)

	s.mu.Lock()
	if existingCh, exists := s.subs[user.ID]; exists {
		close(existingCh)
	}
	s.subs[user.ID] = ch
	delete(s.lastSubTime, user.ID)
	s.mu.Unlock()

	s.publishPresence(user.ID)

	if err := s.store.Presence.Upsert(stream.Context(), user.ID); err != nil {
		logger.L().Error("Failed to upsert presence", zap.Error(err))
	}

	stream.SendHeader(metadata.MD{})

	defer func() {
		s.mu.Lock()
		if s.subs[user.ID] == ch {
			delete(s.subs, user.ID)
			s.lastSubTime[user.ID] = time.Now()
		}
		s.mu.Unlock()
	}()

	for {
		select {
		case <-stream.Context().Done():
			return nil
		case event, ok := <-ch:
			if !ok {
				return nil
			}

			if err := stream.Send(event); err != nil {
				return err
			}
		}
	}
}

func (s *PartyService) LeaveParty(ctx context.Context, _ *pbcommon.Empty) (*pbcommon.Empty, error) {
	user := ctx.Value("user").(*models.UserModel)

	party, err := s.store.Parties.GetByMemberID(ctx, user.ID)
	if err != nil {
		logger.L().Error("Failed to get party", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get party")
	}

	if party == nil {
		return nil, status.Error(codes.NotFound, "You are not in a party")
	}

	if err = s.handleLeave(ctx, party, user.ID); err != nil {
		return nil, status.Error(codes.Internal, "Failed to handle leave")
	}

	logger.L().Info("User left party", zap.Uint64("party_id", party.ID), zap.String("user_id", user.ID))

	return &pbcommon.Empty{}, nil
}

func (s *PartyService) InvitePlayer(ctx context.Context, req *pbapi.InvitePlayerRequest) (*pbcommon.Empty, error) {
	user := ctx.Value("user").(*models.UserModel)

	party, err := s.store.Parties.GetByMemberID(ctx, user.ID)
	if err != nil {
		logger.L().Error("Failed to get party", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get party")
	}

	if party == nil {
		party, err = s.createParty(ctx, *user)
		if err != nil {
			return nil, status.Error(codes.Internal, "Failed to create party")
		}
	}

	inviteeParty, err := s.store.Parties.GetByMemberID(ctx, req.UserId)
	if err != nil {
		logger.L().Error("Failed to check invitee party", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to check invitee party")
	}

	if inviteeParty != nil {
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

	s.publishPartyEvent(&PartyEventMessage{
		PartyID: party.ID,
		UserIDs: []string{req.UserId},
		Event: &pbapi.PartyEvent{
			Body: &pbapi.PartyEvent_InviteReceived{
				InviteReceived: &pbapi.InviteReceivedEvent{
					PartyId:     party.ID,
					Inviter:     user.Proto(),
					InviteToken: invite.ID,
					ExpiresAt:   invite.ExpiresAt.Unix(),
				},
			},
		},
	})

	logger.L().Info("Sent party invite", zap.Uint64("party_id", party.ID), zap.String("inviter_id", user.ID), zap.String("invitee_id", req.UserId))

	return &pbcommon.Empty{}, nil
}

func (s *PartyService) AcceptInvite(ctx context.Context, req *pbapi.AcceptInviteRequest) (*pbcommon.Empty, error) {
	user := ctx.Value("user").(*models.UserModel)

	existingParty, err := s.store.Parties.GetByMemberID(ctx, user.ID)
	if err != nil {
		logger.L().Error("Failed to check existing party", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to check existing party")
	}

	if existingParty != nil {
		return nil, status.Error(codes.AlreadyExists, "You are already in a party")
	}

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

	if time.Now().After(invite.ExpiresAt) {
		if err := s.store.Parties.Update(ctx, party.ID, bson.M{
			"$pull": bson.M{"invites": bson.M{"invitee_id": user.ID}},
		}); err != nil {
			logger.L().Error("Failed to remove expired invite", zap.Error(err))
		}
		return nil, status.Error(codes.DeadlineExceeded, "Invite has expired")
	}

	memberIDs := s.getAllMemberIDs(party)

	newMember := models.PartyMemberModel{
		UserID:   user.ID,
		JoinedAt: time.Now(),
	}
	if err := s.store.Parties.Update(ctx, party.ID, bson.M{
		"$push": bson.M{"members": newMember},
		"$pull": bson.M{"invites": bson.M{"invitee_id": user.ID}},
	}); err != nil {
		logger.L().Error("Failed to accept invite", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to accept invite")
	}

	allMemberIDs := append(memberIDs, user.ID)
	s.publishPartyEvent(&PartyEventMessage{
		PartyID: party.ID,
		UserIDs: allMemberIDs,
		Event: &pbapi.PartyEvent{
			Body: &pbapi.PartyEvent_MemberJoined{
				MemberJoined: &pbapi.MemberJoinedEvent{
					User: user.Proto(),
				},
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

	s.publishPartyEvent(&PartyEventMessage{
		PartyID: party.ID,
		UserIDs: s.getAllMemberIDs(party),
		Event: &pbapi.PartyEvent{
			Body: &pbapi.PartyEvent_InviteDeclined{
				InviteDeclined: &pbapi.InviteDeclinedEvent{
					User: user.Proto(),
				},
			},
		},
	})

	logger.L().Info("User declined party invite", zap.Uint64("party_id", party.ID), zap.String("user_id", user.ID))

	return &pbcommon.Empty{}, nil
}

func (s *PartyService) GetParty(ctx context.Context, _ *pbcommon.Empty) (*pbapi.GetPartyResponse, error) {
	user := ctx.Value("user").(*models.UserModel)

	party, err := s.store.Parties.GetByMemberID(ctx, user.ID)
	if err != nil {
		logger.L().Error("Failed to get party", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get party")
	}

	if party == nil {
		return &pbapi.GetPartyResponse{}, nil
	}

	users, err := s.store.Users.SearchByIDs(ctx, s.getAllMemberIDs(party))
	if err != nil {
		logger.L().Error("Failed to get member users", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get member users")
	}

	if len(users) != len(party.Members) {
		logger.L().Warn("Mismatch in number of users and party members", zap.Int("users", len(users)), zap.Int("members", len(party.Members)))
		return nil, status.Error(codes.Internal, "Failed to get all member users")
	}

	mapped := make(map[string]*models.UserModel)
	for _, user := range users {
		mapped[user.ID] = user
	}

	return &pbapi.GetPartyResponse{Party: party.Proto(mapped)}, nil
}

func (s *PartyService) createParty(ctx context.Context, user models.UserModel) (*models.PartyModel, error) {
	partyID, err := s.store.Parties.GetNextID(ctx)
	if err != nil {
		logger.L().Error("Failed to get next party ID", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to generate party ID")
	}

	party := &models.PartyModel{
		ID:       partyID,
		LeaderID: user.ID,
		Members: []models.PartyMemberModel{
			{
				UserID:   user.ID,
				JoinedAt: time.Now(),
			},
		},
		CreatedAt: time.Now(),
	}

	if err := s.store.Parties.Create(ctx, party); err != nil {
		logger.L().Error("Failed to create party", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to create party")
	}

	logger.L().Info("Created party", zap.Uint64("party_id", party.ID), zap.String("leader_id", user.ID))

	return party, nil
}

func (s *PartyService) publishPartyEvent(msg *PartyEventMessage) {
	eventBytes, err := protojson.Marshal(msg.Event)
	if err != nil {
		logger.L().Error("Failed to marshal party event proto", zap.Error(err))
		return
	}

	wire := partyEventWire{
		PartyID: msg.PartyID,
		UserIDs: msg.UserIDs,
		Event:   json.RawMessage(eventBytes),
	}

	data, err := json.Marshal(wire)
	if err != nil {
		logger.L().Error("Failed to marshal party event", zap.Error(err))
		return
	}

	err = s.mq.Channel.Publish(
		"party_events",
		"",
		false,
		false,
		amqp.Publishing{
			ContentType: "application/json",
			Body:        data,
		},
	)

	if err != nil {
		logger.L().Error("Failed to publish party event", zap.Error(err))
	}
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
		var wire partyEventWire
		if err := json.Unmarshal(msg.Body, &wire); err != nil {
			logger.L().Error("Failed to unmarshal party event wire", zap.Error(err))
			continue
		}

		var event pbapi.PartyEvent
		if err := protojson.Unmarshal(wire.Event, &event); err != nil {
			logger.L().Error("Failed to unmarshal party event proto", zap.Error(err))
			continue
		}

		s.mu.RLock()
		for _, userID := range wire.UserIDs {
			if ch, ok := s.subs[userID]; ok {
				select {
				case ch <- &event:
				default:
					logger.L().Warn("Dropping party event for user", zap.String("user_id", userID), zap.Uint64("party_id", wire.PartyID))
				}
			}
		}
		s.mu.RUnlock()
	}
}

func (s *PartyService) publishPresence(userID string) {
	data, err := json.Marshal(map[string]string{"user_id": userID})
	if err != nil {
		logger.L().Error("Failed to marshal presence event", zap.Error(err))
		return
	}

	err = s.mq.Channel.Publish("party_presence", "", false, false, amqp.Publishing{
		ContentType: "application/json",
		Body:        data,
	})
	if err != nil {
		logger.L().Error("Failed to publish presence event", zap.Error(err))
	}
}

func (s *PartyService) consumePresenceEvents() {
	q, err := s.mq.Channel.QueueDeclare("", false, true, true, false, nil)
	if err != nil {
		logger.L().Error("Failed to declare presence queue", zap.Error(err))
		return
	}

	if err = s.mq.Channel.QueueBind(q.Name, "", "party_presence", false, nil); err != nil {
		logger.L().Error("Failed to bind presence queue", zap.Error(err))
		return
	}

	msgs, err := s.mq.Channel.Consume(q.Name, "", true, false, false, false, nil)
	if err != nil {
		logger.L().Error("Failed to consume presence events", zap.Error(err))
		return
	}

	for msg := range msgs {
		var event struct {
			UserID string `json:"user_id"`
		}
		if err := json.Unmarshal(msg.Body, &event); err != nil {
			logger.L().Error("Failed to unmarshal presence event", zap.Error(err))
			continue
		}

		s.mu.Lock()
		delete(s.lastSubTime, event.UserID)
		s.mu.Unlock()
	}
}

func (s *PartyService) getAllMemberIDs(party *models.PartyModel) []string {
	ids := make([]string, len(party.Members))
	for i, member := range party.Members {
		ids[i] = member.UserID
	}
	return ids
}

func (s *PartyService) cleanupDisconnectedPlayers() {
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()

	for range ticker.C {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)

		s.mu.RLock()
		var disconnectedUsers []string
		for userID, disconnectTime := range s.lastSubTime {
			if _, subscribed := s.subs[userID]; !subscribed {
				if time.Now().Sub(disconnectTime) > 10*time.Second {
					disconnectedUsers = append(disconnectedUsers, userID)
				}
			}
		}
		s.mu.RUnlock()

		for _, userID := range disconnectedUsers {
			party, err := s.store.Parties.GetByMemberID(ctx, userID)
			if err != nil {
				logger.L().Error("Failed to get party for disconnected user", zap.Error(err), zap.String("user_id", userID))
				continue
			}

			if party == nil {
				s.mu.Lock()
				delete(s.lastSubTime, userID)
				s.mu.Unlock()
				continue
			}

			s.handleLeave(ctx, party, userID)

			logger.L().Info("Removed disconnected user from party", zap.Uint64("party_id", party.ID), zap.String("user_id", userID))

			s.mu.Lock()
			delete(s.lastSubTime, userID)
			s.mu.Unlock()
		}

		cancel()
	}
}

func (s *PartyService) heartbeatPresence() {
	ticker := time.NewTicker(10 * time.Second)
	defer ticker.Stop()

	for range ticker.C {
		s.mu.RLock()
		userIDs := make([]string, 0, len(s.subs))
		for userID := range s.subs {
			userIDs = append(userIDs, userID)
		}
		s.mu.RUnlock()

		if len(userIDs) == 0 {
			continue
		}

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		if err := s.store.Presence.UpsertMany(ctx, userIDs); err != nil {
			logger.L().Error("Failed to heartbeat presence", zap.Error(err))
		}
		cancel()
	}
}

func (s *PartyService) cleanupOrphanedMembers() {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for range ticker.C {
		ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)

		parties, err := s.store.Parties.GetAll(ctx)
		if err != nil {
			logger.L().Error("Failed to get all parties for orphan cleanup", zap.Error(err))
			cancel()
			continue
		}

		allMemberIDs := make(map[string]bool)
		for _, party := range parties {
			for _, member := range party.Members {
				allMemberIDs[member.UserID] = true
			}
		}

		if len(allMemberIDs) == 0 {
			cancel()
			continue
		}

		memberIDList := make([]string, 0, len(allMemberIDs))
		for id := range allMemberIDs {
			memberIDList = append(memberIDList, id)
		}

		existing, err := s.store.Presence.FindExisting(ctx, memberIDList)
		if err != nil {
			logger.L().Error("Failed to check presence for orphan cleanup", zap.Error(err))
			cancel()
			continue
		}

		existingSet := make(map[string]bool, len(existing))
		for _, id := range existing {
			existingSet[id] = true
		}

		for _, party := range parties {
			for _, member := range party.Members {
				if !existingSet[member.UserID] {
					if err := s.handleLeave(ctx, party, member.UserID); err != nil {
						logger.L().Error("Failed to remove member", zap.Error(err), zap.String("user_id", member.UserID), zap.Uint64("party_id", party.ID))
					} else {
						logger.L().Info("Removed member from party", zap.Uint64("party_id", party.ID), zap.String("user_id", member.UserID))
					}
				}
			}
		}

		cancel()
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

func (s *PartyService) handleLeave(ctx context.Context, party *models.PartyModel, userID string) error {
	if len(party.Members) == 1 {
		if err := s.store.Parties.Delete(ctx, party.ID); err != nil {
			logger.L().Error("Failed to delete party", zap.Error(err))
			return status.Error(codes.Internal, "Failed to delete party")
		}
	} else {
		update := bson.M{
			"$pull": bson.M{"members": bson.M{"user_id": userID}},
		}

		if err := s.store.Parties.Update(ctx, party.ID, update); err != nil {
			logger.L().Error("Failed to update party", zap.Error(err))
			return status.Error(codes.Internal, "Failed to update party")
		}
	}

	s.publishPartyEvent(&PartyEventMessage{
		PartyID: party.ID,
		UserIDs: s.getAllMemberIDs(party),
		Event: &pbapi.PartyEvent{
			Body: &pbapi.PartyEvent_MemberLeft{
				MemberLeft: &pbapi.MemberLeftEvent{
					UserId: userID,
				},
			},
		},
	})

	return nil
}
