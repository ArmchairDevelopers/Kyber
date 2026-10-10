package models

import (
	"time"

	"github.com/ArmchairDevelopers/Kyber/API/api/v1/pbapi"
)

type QueueEntryState string

const (
	QueueEntryStateWaiting  QueueEntryState = "waiting"
	QueueEntryStateReserved QueueEntryState = "reserved"
)

type QueueEntryModel struct {
	ID                   string          `json:"id" bson:"_id"`
	ServerID             string          `json:"server_id" bson:"server_id"`
	PartyID              *uint64         `json:"party_id,omitempty" bson:"party_id,omitempty"`
	UserID               *string         `json:"user_id,omitempty" bson:"user_id,omitempty"`
	State                QueueEntryState `json:"state" bson:"state"`
	EnqueuedAt           time.Time       `json:"enqueued_at" bson:"enqueued_at"`
	ReservationExpiresAt *time.Time      `json:"reservation_expires_at,omitempty" bson:"reservation_expires_at,omitempty"`
	MemberIDs            []string        `json:"member_ids,omitempty" bson:"member_ids,omitempty"`
	ClaimedIDs           []string        `json:"claimed_ids,omitempty" bson:"claimed_ids,omitempty"`
}

func (e *QueueEntryModel) ProtoState() pbapi.QueueEntryState {
	if e.State == QueueEntryStateReserved {
		return pbapi.QueueEntryState_QUEUE_STATE_RESERVED
	}

	return pbapi.QueueEntryState_QUEUE_STATE_WAITING
}

func (e *QueueEntryModel) ReservedSlots(now time.Time) int {
	if e.State != QueueEntryStateReserved {
		return 0
	}

	if e.ReservationExpiresAt != nil && now.After(*e.ReservationExpiresAt) {
		return 0
	}

	reserved := len(e.MemberIDs) - len(e.ClaimedIDs)
	if reserved < 0 {
		return 0
	}

	return reserved
}
