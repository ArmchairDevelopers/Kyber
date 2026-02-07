package models

import "time"

type PartyInviteModel struct {
	ID        string    `json:"id" bson:"_id"`
	InviterID string    `json:"inviter_id" bson:"inviter_id"`
	PartyID   uint64    `json:"party_id" bson:"party_id"`
	InviteeID string    `json:"invitee_id" bson:"invitee_id"`
	CreatedAt time.Time `json:"created_at" bson:"created_at"`
	ExpiresAt time.Time `json:"expires_at" bson:"expires_at"`
}
