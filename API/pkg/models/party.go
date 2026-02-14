package models

import (
	"time"

	"github.com/ArmchairDevelopers/Kyber/API/api/v1/pbapi"
)

type PartyModel struct {
	ID        uint64    `json:"id" bson:"_id"`
	LeaderID  string    `json:"leader_id" bson:"leader_id"`
	CreatedAt time.Time `json:"created_at" bson:"created_at"`
}

func (p *PartyModel) Proto(sessions []SessionModel, users map[string]*UserModel) *pbapi.PartyState {
	members := make([]*pbapi.PartyMember, 0, len(sessions))
	for _, session := range sessions {
		user, ok := users[session.UserID]
		if !ok {
			continue
		}
		members = append(members, &pbapi.PartyMember{
			Player: user.Proto(),
			// TODO: save the actual joined at timestamp
			JoinedAt: session.LoginAt.Unix(),
		})
	}

	return &pbapi.PartyState{
		Id:        p.ID,
		LeaderId:  p.LeaderID,
		Members:   members,
		CreatedAt: p.CreatedAt.Unix(),
	}
}
