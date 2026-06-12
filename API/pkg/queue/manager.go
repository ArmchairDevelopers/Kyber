package queue

import (
	"context"
	"time"

	"github.com/ArmchairDevelopers/Kyber/API/api/v1/pbapi"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/db"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/logger"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/models"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/mq"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/util"
	"go.uber.org/zap"
)

const (
	sweepInterval = 10 * time.Second
)

type Manager struct {
	store *db.Store
	pub   *mq.QueueEventPublisher
}

func NewManager(store *db.Store, pub *mq.QueueEventPublisher) *Manager {
	m := &Manager{
		store: store,
		pub:   pub,
	}

	go m.sweepLoop()

	return m
}

func (m *Manager) ShouldQueue(ctx context.Context, server *models.ServerModel) (bool, error) {
	free, err := m.freeSlots(ctx, server)
	if err != nil {
		return false, err
	}

	if free <= 0 {
		return true, nil
	}

	active, err := m.store.Queues.HasWaitingOrReserved(ctx, server.ID, time.Now())
	if err != nil {
		return false, err
	}

	return active, nil
}

func (m *Manager) Enqueue(ctx context.Context, server *models.ServerModel, partyID *uint64, userID *string) (*models.QueueEntryModel, error) {
	entry := &models.QueueEntryModel{
		ID:         util.GenerateToken(),
		ServerID:   server.ID,
		PartyID:    partyID,
		UserID:     userID,
		State:      models.QueueEntryStateWaiting,
		EnqueuedAt: time.Now(),
	}

	if err := m.store.Queues.Create(ctx, entry); err != nil {
		return nil, err
	}

	return entry, nil
}

func (m *Manager) Status(ctx context.Context, entry *models.QueueEntryModel) *pbapi.QueueStatus {
	status := &pbapi.QueueStatus{
		ServerId: entry.ServerID,
		State:    entry.ProtoState(),
	}

	waiting, err := m.store.Queues.GetWaitingByServer(ctx, entry.ServerID)
	if err != nil {
		logger.L().Error("Failed to get waiting queue entries", zap.Error(err))
		return status
	}

	status.QueueSize = uint32(len(waiting))
	for i, w := range waiting {
		if w.ID == entry.ID {
			status.Position = uint32(i) + 1
			break
		}
	}

	return status
}

func (m *Manager) Advance(ctx context.Context, serverID string) {
	waiting, err := m.store.Queues.GetWaitingByServer(ctx, serverID)
	if err != nil {
		logger.L().Error("Failed to get waiting queue entries", zap.Error(err), zap.String("server_id", serverID))
		return
	}

	if len(waiting) == 0 {
		return
	}

	owner := util.GenerateToken()
	locked, err := m.store.Queues.AcquireServerLock(ctx, serverID, owner, 15*time.Second)
	if err != nil {
		logger.L().Error("Failed to acquire queue advance lock", zap.Error(err), zap.String("server_id", serverID))
		return
	}

	if !locked {
		return
	}

	defer func() {
		if err := m.store.Queues.ReleaseServerLock(ctx, serverID, owner); err != nil {
			logger.L().Error("Failed to release queue advance lock", zap.Error(err), zap.String("server_id", serverID))
		}
	}()

	server, err := m.store.Servers.GetByID(ctx, serverID)
	if err != nil {
		logger.L().Error("Failed to get server for queue reservation", zap.Error(err), zap.String("server_id", serverID))
		return
	}

	if server == nil {
		m.HandleServersDeleted(ctx, []string{serverID})
		return
	}

	waiting, err = m.store.Queues.GetWaitingByServer(ctx, serverID)
	if err != nil {
		logger.L().Error("Failed to get waiting queue entries", zap.Error(err), zap.String("server_id", serverID))
		return
	}

	free, err := m.freeSlots(ctx, server)
	if err != nil {
		logger.L().Error("Failed to compute free slots", zap.Error(err), zap.String("server_id", serverID))
		return
	}

	reserved := false
	for _, entry := range waiting {
		if free <= 0 {
			break
		}

		members := m.liveMemberIDs(ctx, entry)
		if len(members) == 0 {
			m.removeEntry(ctx, entry, pbapi.QueueRemovedReason_QUEUE_REMOVED_LEFT, false)
			continue
		}

		if !m.isReady(ctx, entry, members) {
			continue
		}

		if len(members) > free {
			break
		}

		ok, err := m.store.Queues.MarkReserved(ctx, entry.ID, members, time.Now().Add(90*time.Second))
		if err != nil {
			logger.L().Error("Failed to reserve slots for queue", zap.Error(err), zap.String("entry_id", entry.ID))
			break
		}

		if !ok {
			continue
		}

		logger.L().Info("Reserved queue slots", zap.String("entry_id", entry.ID), zap.String("server_id", serverID), zap.Int("size", len(members)))

		m.pub.Publish(members, &pbapi.QueueEvent{
			Body: &pbapi.QueueEvent_QueueUpdated{
				QueueUpdated: &pbapi.QueueUpdatedEvent{
					Status: &pbapi.QueueStatus{
						ServerId: entry.ServerID,
						State:    pbapi.QueueEntryState_QUEUE_STATE_RESERVED,
					},
				},
			},
		})

		reserved = true
		free -= len(members)
	}

	if reserved {
		m.BroadcastPositions(ctx, serverID)
	}
}

func (m *Manager) MarkSlotClaimed(ctx context.Context, entry *models.QueueEntryModel, userID string) {
	updated, err := m.store.Queues.AddClaimedTokenID(ctx, entry.ID, userID)
	if err != nil {
		logger.L().Error("Failed to mark queue slot claimed", zap.Error(err), zap.String("entry_id", entry.ID))
		return
	}

	if updated == nil {
		return
	}

	claimed := make(map[string]bool, len(updated.ClaimedIDs))
	for _, id := range updated.ClaimedIDs {
		claimed[id] = true
	}

	for _, id := range updated.MemberIDs {
		if !claimed[id] {
			return
		}
	}

	if _, err := m.store.Queues.Delete(ctx, updated.ID); err != nil {
		logger.L().Error("Failed to delete consumed queue entry", zap.Error(err), zap.String("entry_id", updated.ID))
	}
}

func (m *Manager) RemoveByPartyID(ctx context.Context, partyID uint64, reason pbapi.QueueRemovedReason) {
	entry, err := m.store.Queues.GetByPartyID(ctx, partyID)
	if err != nil {
		logger.L().Error("Failed to get queue entry by party", zap.Error(err), zap.Uint64("party_id", partyID))
		return
	}

	if entry == nil {
		return
	}

	m.removeEntry(ctx, entry, reason, true)
}

func (m *Manager) RemoveByUserID(ctx context.Context, userID string, reason pbapi.QueueRemovedReason) {
	entry, err := m.store.Queues.GetByUserID(ctx, userID)
	if err != nil {
		logger.L().Error("Failed to get queue entry by user", zap.Error(err), zap.String("user_id", userID))
		return
	}

	if entry == nil {
		return
	}

	m.removeEntry(ctx, entry, reason, true)
}

func (m *Manager) RemoveEntry(ctx context.Context, entry *models.QueueEntryModel, reason pbapi.QueueRemovedReason) {
	m.removeEntry(ctx, entry, reason, true)
}

func (m *Manager) HandleServersDeleted(ctx context.Context, serverIDs []string) {
	if len(serverIDs) == 0 {
		return
	}

	entries, err := m.store.Queues.GetByServerIDs(ctx, serverIDs)
	if err != nil {
		logger.L().Error("Failed to get queue entries for servers", zap.Error(err))
		return
	}

	for _, entry := range entries {
		ok, err := m.store.Queues.Delete(ctx, entry.ID)
		if err != nil {
			logger.L().Error("Failed to delete queue entry", zap.Error(err), zap.String("entry_id", entry.ID))
			continue
		}

		if ok {
			m.publishRemoved(ctx, entry, pbapi.QueueRemovedReason_QUEUE_REMOVED_SERVER_SHUTDOWN)
		}
	}
}

func (m *Manager) BroadcastPositions(ctx context.Context, serverID string) {
	waiting, err := m.store.Queues.GetWaitingByServer(ctx, serverID)
	if err != nil {
		logger.L().Error("Failed to get waiting queue entries", zap.Error(err), zap.String("server_id", serverID))
		return
	}

	for i, entry := range waiting {
		members := m.liveMemberIDs(ctx, entry)
		if len(members) == 0 {
			continue
		}

		m.pub.Publish(members, &pbapi.QueueEvent{
			Body: &pbapi.QueueEvent_QueueUpdated{
				QueueUpdated: &pbapi.QueueUpdatedEvent{
					Status: &pbapi.QueueStatus{
						ServerId:  entry.ServerID,
						Position:  uint32(i) + 1,
						QueueSize: uint32(len(waiting)),
						State:     pbapi.QueueEntryState_QUEUE_STATE_WAITING,
					},
				},
			},
		})
	}
}

func (m *Manager) OnPartyMemberReady(ctx context.Context, partyID uint64) {
	entry, err := m.store.Queues.GetByPartyID(ctx, partyID)
	if err != nil {
		logger.L().Error("Failed to get queue entry by party", zap.Error(err), zap.Uint64("party_id", partyID))
		return
	}

	if entry == nil || entry.State != models.QueueEntryStateWaiting {
		return
	}

	go m.Advance(context.WithoutCancel(ctx), entry.ServerID)
}

func (m *Manager) removeEntry(ctx context.Context, entry *models.QueueEntryModel, reason pbapi.QueueRemovedReason, advance bool) {
	ok, err := m.store.Queues.Delete(ctx, entry.ID)
	if err != nil {
		logger.L().Error("Failed to delete queue entry", zap.Error(err), zap.String("entry_id", entry.ID))
		return
	}

	if !ok {
		return
	}

	m.publishRemoved(ctx, entry, reason)

	if entry.State == models.QueueEntryStateWaiting {
		m.BroadcastPositions(ctx, entry.ServerID)
	}

	if advance {
		go m.Advance(context.WithoutCancel(ctx), entry.ServerID)
	}
}

func (m *Manager) publishRemoved(ctx context.Context, entry *models.QueueEntryModel, reason pbapi.QueueRemovedReason) {
	members := m.liveMemberIDs(ctx, entry)
	if len(members) == 0 {
		members = entry.MemberIDs
	}

	m.pub.Publish(members, &pbapi.QueueEvent{
		Body: &pbapi.QueueEvent_QueueRemoved{
			QueueRemoved: &pbapi.QueueRemovedEvent{
				ServerId: entry.ServerID,
				Reason:   reason,
			},
		},
	})
}

func (m *Manager) freeSlots(ctx context.Context, server *models.ServerModel) (int, error) {
	entries, err := m.store.Queues.GetReservedByServer(ctx, server.ID)
	if err != nil {
		return 0, err
	}

	now := time.Now()
	reserved := 0
	for _, entry := range entries {
		reserved += entry.ReservedSlots(now)
	}

	occupancy := max(int(server.PlayerCount), int(server.PlayerCount))

	return int(server.MaxPlayerCount) - occupancy - reserved, nil
}

func (m *Manager) liveMemberIDs(ctx context.Context, entry *models.QueueEntryModel) []string {
	if entry.PartyID != nil {
		sessions, err := m.store.Sessions.GetByPartyID(ctx, *entry.PartyID)
		if err != nil {
			logger.L().Error("Failed to get party sessions for queue entry", zap.Error(err), zap.String("entry_id", entry.ID))
			return nil
		}

		return models.GetUserIDsFromSessions(sessions)
	}

	if entry.UserID != nil {
		session, err := m.store.Sessions.GetByUserID(ctx, *entry.UserID)
		if err != nil {
			logger.L().Error("Failed to get session for queue entry", zap.Error(err), zap.String("entry_id", entry.ID))
			return nil
		}

		if session == nil || session.PartyID != nil {
			return nil
		}

		return []string{*entry.UserID}
	}

	return nil
}

func (m *Manager) isReady(ctx context.Context, entry *models.QueueEntryModel, members []string) bool {
	if entry.PartyID == nil {
		return true
	}

	party, err := m.store.Parties.GetByID(ctx, *entry.PartyID)
	if err != nil {
		logger.L().Error("Failed to get party for queue entry", zap.Error(err), zap.String("entry_id", entry.ID))
		return false
	}

	if party == nil || party.JoinGameState == nil || party.JoinGameState.ServerID != entry.ServerID {
		return false
	}

	hasMods := make(map[string]bool, len(party.JoinGameState.MemberStatuses))
	for _, st := range party.JoinGameState.MemberStatuses {
		hasMods[st.UserID] = st.HasMods
	}

	for _, member := range members {
		if !hasMods[member] {
			return false
		}
	}

	return true
}

func (m *Manager) sweepLoop() {
	ticker := time.NewTicker(sweepInterval)
	defer ticker.Stop()

	for range ticker.C {
		func() {
			defer func() {
				if r := recover(); r != nil {
					logger.L().Error("Queue sweep panicked", zap.Any("panic", r))
				}
			}()

			ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
			defer cancel()

			locked, err := m.store.Queues.AcquireServerLock(ctx, "sweep_leader", util.GenerateToken(), sweepInterval)
			if err != nil {
				logger.L().Error("Failed to acquire sweep leader lease", zap.Error(err))
				return
			}

			if !locked {
				return
			}

			m.sweep(ctx)
		}()
	}
}

func (m *Manager) sweep(ctx context.Context) {
	entries, err := m.store.Queues.GetAll(ctx)
	if err != nil {
		logger.L().Error("Failed to get queue entries for sweep", zap.Error(err))
		return
	}

	now := time.Now()
	retryServers := make(map[string]bool)

	for _, entry := range entries {
		if entry.State == models.QueueEntryStateReserved {
			if entry.ReservationExpiresAt != nil && now.After(*entry.ReservationExpiresAt) {
				logger.L().Info("Queue reservation expired", zap.String("entry_id", entry.ID), zap.String("server_id", entry.ServerID))
				m.removeEntry(ctx, entry, pbapi.QueueRemovedReason_QUEUE_REMOVED_TIMEOUT, false)
				retryServers[entry.ServerID] = true
			}
			continue
		}

		members := m.liveMemberIDs(ctx, entry)
		if len(members) == 0 {
			m.removeEntry(ctx, entry, pbapi.QueueRemovedReason_QUEUE_REMOVED_LEFT, false)
			retryServers[entry.ServerID] = true
			continue
		}

		if entry.PartyID != nil {
			party, err := m.store.Parties.GetByID(ctx, *entry.PartyID)
			if err != nil {
				continue
			}

			if party == nil || party.JoinGameState == nil || party.JoinGameState.ServerID != entry.ServerID {
				m.removeEntry(ctx, entry, pbapi.QueueRemovedReason_QUEUE_REMOVED_LEFT, false)
				retryServers[entry.ServerID] = true
				continue
			}
		}

		retryServers[entry.ServerID] = true
	}

	for serverID := range retryServers {
		m.Advance(ctx, serverID)
	}
}
