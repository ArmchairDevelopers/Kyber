package models

import "time"

type SessionModel struct {
	UserID      string     `json:"user_id" bson:"_id"`
	PartyID     *uint64    `json:"party_id,omitempty" bson:"party_id,omitempty"`
	IP          string     `json:"ip" bson:"ip"`
	Version     string     `json:"version" bson:"version"`
	Status      string     `json:"status" bson:"status"`
	LoginAt     time.Time  `json:"login_at" bson:"login_at"`
	ReconnectAt *time.Time `json:"reconnect_at,omitempty" bson:"reconnect_at,omitempty"`
	UpdatedAt   time.Time  `json:"updated_at" bson:"updated_at"`
}
