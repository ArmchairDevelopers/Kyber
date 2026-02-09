package models

import "time"

type PartyPresenceModel struct {
	UserID    string    `json:"user_id" bson:"_id"`
	UpdatedAt time.Time `json:"updated_at" bson:"updated_at"`
}
