package ws

import (
	"context"
	"net/http"
	"sync"
	"time"

	"github.com/ArmchairDevelopers/Kyber/API/api/v1/pbapi"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/db"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/logger"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/models"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/mq"
	"github.com/gorilla/websocket"
	"go.mongodb.org/mongo-driver/bson"
	"go.uber.org/zap"
	"google.golang.org/protobuf/proto"
)

const sessionMaxAge = 30 * time.Second

type sessionSub struct {
	ch   chan *pbapi.SessionEvent
	conn *websocket.Conn
}

type SessionManager struct {
	store    *db.Store
	partyPub *mq.PartyEventPublisher
	mu       sync.RWMutex
	subs     map[string]*sessionSub
}

func NewSessionManager(store *db.Store, partyPub *mq.PartyEventPublisher) *SessionManager {
	s := &SessionManager{
		store:    store,
		partyPub: partyPub,
		subs:     make(map[string]*sessionSub),
	}

	go s.heartbeatSessions()
	go s.cleanupStaleSessions()

	return s
}

func (s *SessionManager) Send(userIDs []string, event *pbapi.SessionEvent) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	for _, userID := range userIDs {
		if sub, ok := s.subs[userID]; ok {
			select {
			case sub.ch <- event:
			default:
				logger.L().Warn("Dropping session event for user", zap.String("user_id", userID))
			}
		}
	}
}

func (s *SessionManager) heartbeatSessions() {
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

		if err := s.store.Sessions.TouchMany(ctx, userIDs); err != nil {
			logger.L().Error("Failed to heartbeat sessions", zap.Error(err))
		}

		cancel()
	}
}

func (s *SessionManager) cleanupStaleSessions() {
	ticker := time.NewTicker(20 * time.Second)
	defer ticker.Stop()

	for range ticker.C {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)

		stale, err := s.store.Sessions.DeleteStale(ctx, sessionMaxAge)
		cancel()

		if err != nil {
			logger.L().Error("Failed to cleanup stale sessions", zap.Error(err))
			continue
		}

		for _, session := range stale {
			s.handleSessionEnded(session)
		}
	}
}

func (s *SessionManager) handleSessionEnded(session models.SessionModel) {
	logger.L().Debug("Session expired", zap.String("user_id", session.UserID))

	if session.PartyID == nil {
		return
	}

	partyID := *session.PartyID

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	remainingSessions, err := s.store.Sessions.GetByPartyID(ctx, partyID)
	cancel()

	if err != nil {
		logger.L().Error("Failed to get remaining sessions", zap.Error(err))
		return
	}

	if len(remainingSessions) < 2 {
		delCtx, delCancel := context.WithTimeout(context.Background(), 5*time.Second)
		if err := s.store.Parties.Delete(delCtx, partyID); err != nil {
			logger.L().Error("Failed to delete empty party", zap.Error(err))
		}
		delCancel()

		for _, sess := range remainingSessions {
			clearCtx, clearCancel := context.WithTimeout(context.Background(), 5*time.Second)
			if err := s.store.Sessions.SetPartyID(clearCtx, sess.UserID, nil); err != nil {
				logger.L().Error("Failed to clear party ID on remaining session", zap.Error(err))
			}
			clearCancel()
		}

		if len(remainingSessions) > 0 {
			s.partyPub.Publish(partyID, []string{remainingSessions[0].UserID}, &pbapi.PartyEvent{
				Body: &pbapi.PartyEvent_MemberLeft{
					MemberLeft: &pbapi.MemberLeftEvent{
						UserId: session.UserID,
					},
				},
			})
		}
		return
	}

	memberIDs := make([]string, len(remainingSessions))
	for i, sess := range remainingSessions {
		memberIDs[i] = sess.UserID
	}

	s.partyPub.Publish(partyID, memberIDs, &pbapi.PartyEvent{
		Body: &pbapi.PartyEvent_MemberLeft{
			MemberLeft: &pbapi.MemberLeftEvent{
				UserId: session.UserID,
			},
		},
	})

	partyCtx, partyCancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer partyCancel()

	party, err := s.store.Parties.GetByID(partyCtx, partyID)
	if err != nil || party == nil {
		if err != nil {
			logger.L().Error("Failed to get party after session ended", zap.Error(err))
		}
		return
	}

	if party.LeaderID != session.UserID {
		return
	}

	if party.JoinGameState != nil {
		if err := s.store.Parties.Update(partyCtx, partyID, bson.M{"$unset": bson.M{"join_game_state": ""}}); err != nil {
			logger.L().Error("Failed to clear join game state", zap.Error(err))
		}

		s.partyPub.Publish(partyID, memberIDs, &pbapi.PartyEvent{
			Body: &pbapi.PartyEvent_JoinGameCancelled{
				JoinGameCancelled: &pbapi.JoinGameCancelledEvent{},
			},
		})
	}

	newLeaderID := remainingSessions[0].UserID
	if err := s.store.Parties.Update(partyCtx, partyID, bson.M{"$set": bson.M{"leader_id": newLeaderID}}); err != nil {
		logger.L().Error("Failed to update party leader", zap.Error(err))
		return
	}

	s.partyPub.Publish(partyID, memberIDs, &pbapi.PartyEvent{
		Body: &pbapi.PartyEvent_NewLeader{
			NewLeader: &pbapi.NewLeaderEvent{
				NewLeaderId: newLeaderID,
			},
		},
	})
}

func (s *SessionManager) BroadcastUpdateCheck() {
	event := &pbapi.SessionEvent{
		Body: &pbapi.SessionEvent_CheckForUpdates{
			CheckForUpdates: &pbapi.CheckForUpdatesEvent{},
		},
	}

	s.mu.RLock()
	defer s.mu.RUnlock()

	for userID, sub := range s.subs {
		select {
		case sub.ch <- event:
		default:
			logger.L().Warn("Dropping update check event for user", zap.String("user_id", userID))
		}
	}
}

func (s *SessionManager) HandleWS(w http.ResponseWriter, r *http.Request) {
	token := r.Header.Get("Authorization")
	user, err := s.store.Users.GetByToken(r.Context(), token)
	if err != nil {
		logger.L().Error("Failed to get user by token:", zap.Error(err))
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	if user == nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		logger.L().Error("Upgrade error:", zap.Error(err))
		return
	}

	ip := ""
	if ipHeader := r.Header.Get("CF-Connecting-IP"); ipHeader != "" {
		ip = ipHeader
	}

	if ip == "" {
		logger.L().Warn("No client IP found in headers for session", zap.String("user_id", user.ID))
	}

	version := r.Header.Get("X-Launcher-Version")

	now := time.Now()
	existing, _ := s.store.Sessions.GetByUserID(r.Context(), user.ID)
	if existing != nil {
		existing.IP = ip
		existing.Version = version
		existing.ReconnectAt = &now
		existing.UpdatedAt = now
		if err := s.store.Sessions.Upsert(r.Context(), existing); err != nil {
			logger.L().Error("Failed to update existing session:", zap.Error(err))
		}
	} else {
		session := &models.SessionModel{
			UserID:    user.ID,
			IP:        ip,
			Version:   version,
			Status:    "launcher",
			LoginAt:   now,
			UpdatedAt: now,
		}
		if err := s.store.Sessions.Upsert(r.Context(), session); err != nil {
			logger.L().Error("Failed to create session:", zap.Error(err))
			return
		}
	}

	conn.SetReadLimit(1024 * 1024)
	_ = conn.SetReadDeadline(time.Now().Add(keepAliveTimeout))

	ch := make(chan *pbapi.SessionEvent, 10)

	s.mu.Lock()
	if existing, ok := s.subs[user.ID]; ok {
		existing.conn.Close()
		close(existing.ch)
	}
	s.subs[user.ID] = &sessionSub{ch: ch, conn: conn}
	s.mu.Unlock()

	logger.L().Info("New session connected", zap.String("user_id", user.ID))

	go func() {
		ticker := time.NewTicker(200 * time.Millisecond)
		defer ticker.Stop()
		defer conn.Close()

		for {
			_, msg, err := conn.ReadMessage()
			if err != nil {
				break
			}

			err = conn.SetReadDeadline(time.Now().Add(keepAliveTimeout))
			if err != nil {
				logger.L().Error("Failed to set read deadline:", zap.Error(err))
				return
			}

			if len(msg) > 0 {
				s.handleClientMessage(user.ID, msg)
			}

			<-ticker.C
		}

		s.mu.Lock()
		if sub, ok := s.subs[user.ID]; ok && sub.ch == ch {
			delete(s.subs, user.ID)
		}
		s.mu.Unlock()
	}()

	defer conn.Close()

	for {
		select {
		case <-r.Context().Done():
			return
		case event, ok := <-ch:
			if !ok {
				return
			}

			out, _ := proto.Marshal(event)
			if err := conn.WriteMessage(websocket.BinaryMessage, out); err != nil {
				logger.L().Error("Failed to write to ws:", zap.Error(err))
				return
			}
		}
	}
}

func (s *SessionManager) handleClientMessage(userID string, msg []byte) {
	var clientEvent pbapi.SessionClientEvent
	if err := proto.Unmarshal(msg, &clientEvent); err != nil {
		return
	}

	switch evt := clientEvent.Body.(type) {
	case *pbapi.SessionClientEvent_UpdateJoinGameStatus:
		s.handleJoinGameStatusUpdate(userID, evt.UpdateJoinGameStatus)
	case *pbapi.SessionClientEvent_JoinGameReady:
		s.handleJoinGameReady(userID)
	case *pbapi.SessionClientEvent_GameJoined:
		s.handleJoinedGame(userID, evt.GameJoined.ServerId)
	}
}

func (s *SessionManager) handleJoinedGame(userID string, serverID string) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	session, err := s.store.Sessions.GetByUserID(ctx, userID)
	if err != nil || session == nil || session.PartyID == nil {
		return
	}

	partyID := *session.PartyID

	party, err := s.store.Parties.GetByID(ctx, partyID)
	if err != nil || party == nil || party.JoinGameState == nil {
		return
	}

	if party.JoinGameState.ServerID != serverID {
		return
	}

	statuses := party.JoinGameState.MemberStatuses
	updated := false
	var userStatus models.PartyJoinGameMemberStatus
	for i, status := range statuses {
		if status.UserID == userID {
			if !status.HasMods {
				logger.L().Warn("User joined game without mods status", zap.String("user_id", userID))
			}

			statuses[i] = models.PartyJoinGameMemberStatus{
				UserID:                userID,
				HasMods:               true,
				ModDownloadPercentage: status.ModDownloadPercentage,
				Joined:                true,
			}
			userStatus = statuses[i]
			updated = true
			break
		}
	}

	if !updated {
		return
	}

	s.updateJoinStatus(ctx, partyID, statuses, &userStatus)
}

func (s *SessionManager) handleJoinGameStatusUpdate(userID string, evt *pbapi.UpdateJoinGameStatusEvent) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// only temporarily
	// TODO: find a way to avoid hitting the database on every update, maybee by caching party memberships in memory?
	session, err := s.store.Sessions.GetByUserID(ctx, userID)
	if err != nil || session == nil || session.PartyID == nil {
		return
	}

	partyID := *session.PartyID

	party, err := s.store.Parties.GetByID(ctx, partyID)
	if err != nil || party == nil || party.JoinGameState == nil {
		return
	}

	var userStatus *models.PartyJoinGameMemberStatus
	statuses := party.JoinGameState.MemberStatuses
	updated := false
	for i, st := range statuses {
		if st.UserID == userID {
			statuses[i] = models.PartyJoinGameMemberStatus{
				UserID:                userID,
				HasMods:               evt.HasMods,
				ModDownloadPercentage: evt.ModDownloadPercentage,
				Joined:                statuses[i].Joined,
			}
			userStatus = &statuses[i]
			updated = true
			break
		}
	}

	if !updated {
		userStatus = &models.PartyJoinGameMemberStatus{
			UserID:                userID,
			HasMods:               evt.HasMods,
			ModDownloadPercentage: evt.ModDownloadPercentage,
			Joined:                true,
		}
		statuses = append(statuses, *userStatus)
	}

	s.updateJoinStatus(ctx, partyID, statuses, userStatus)
}

func (s *SessionManager) updateJoinStatus(ctx context.Context, partyID uint64, statuses []models.PartyJoinGameMemberStatus, updatedStatus *models.PartyJoinGameMemberStatus) {
	if err := s.store.Parties.Update(ctx, partyID, bson.M{"$set": bson.M{"join_game_state.member_statuses": statuses}}); err != nil {
		logger.L().Error("Failed to persist join game status", zap.Error(err))
	}

	sessions, err := s.store.Sessions.GetByPartyID(ctx, partyID)
	if err != nil {
		logger.L().Error("Failed to get party sessions", zap.Error(err))
		return
	}

	memberIDs := make([]string, len(sessions))
	for i, sess := range sessions {
		memberIDs[i] = sess.UserID
	}

	s.partyPub.Publish(partyID, memberIDs, &pbapi.PartyEvent{
		Body: &pbapi.PartyEvent_JoinGameStatus{
			JoinGameStatus: &pbapi.JoinGameStatusEvent{
				UserId:                updatedStatus.UserID,
				HasMods:               updatedStatus.HasMods,
				ModDownloadPercentage: updatedStatus.ModDownloadPercentage,
				Joined:                updatedStatus.Joined,
			},
		},
	})
}

func (s *SessionManager) handleJoinGameReady(userID string) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	session, err := s.store.Sessions.GetByUserID(ctx, userID)
	if err != nil || session == nil || session.PartyID == nil {
		return
	}

	partyID := *session.PartyID

	party, err := s.store.Parties.GetByID(ctx, partyID)
	if err != nil || party == nil || party.JoinGameState == nil {
		return
	}

	if party.LeaderID != userID {
		return
	}

	sessions, err := s.store.Sessions.GetByPartyID(ctx, partyID)
	if err != nil {
		logger.L().Error("Failed to get party sessions", zap.Error(err))
		return
	}

	memberIDs := make([]string, len(sessions))
	for i, sess := range sessions {
		memberIDs[i] = sess.UserID
	}

	s.partyPub.Publish(partyID, memberIDs, &pbapi.PartyEvent{
		Body: &pbapi.PartyEvent_JoinGameReady{
			JoinGameReady: &pbapi.JoinGameReadyEvent{},
		},
	})
}
