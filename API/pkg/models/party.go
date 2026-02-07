package models

import (
	"time"

	"github.com/ArmchairDevelopers/Kyber/API/api/v1/pbapi"
)

type PartyModel struct {
	ID       uint64             `json:"id" bson:"_id"`
	LeaderID string             `json:"leader_id" bson:"leader_id"`
	Members  []PartyMemberModel `json:"members" bson:"members"`
	// TODO: maybe move this into a separate collection
	Invites   []PartyInviteModel `json:"invites" bson:"invites"`
	CreatedAt time.Time          `json:"created_at" bson:"created_at"`
}

type PartyMemberModel struct {
	UserID   string    `json:"user_id" bson:"user_id"`
	JoinedAt time.Time `json:"joined_at" bson:"joined_at"`
}

type PartyInviteModel struct {
	InviterID string    `json:"inviter_id" bson:"inviter_id"`
	InviteeID string    `json:"invitee_id" bson:"invitee_id"`
	Token     string    `json:"token" bson:"token"`
	ExpiresAt time.Time `json:"expires_at" bson:"expires_at"`
}

func (p *PartyModel) HasMember(userID string) bool {
	for _, member := range p.Members {
		if member.UserID == userID {
			return true
		}
	}
	return false
}

func (p *PartyModel) RemoveMember(userID string) {
	for i, member := range p.Members {
		if member.UserID == userID {
			p.Members = append(p.Members[:i], p.Members[i+1:]...)
			return
		}
	}
}

func (p *PartyModel) GetInvite(userID string) *PartyInviteModel {
	for _, invite := range p.Invites {
		if invite.InviteeID == userID {
			return &invite
		}
	}
	return nil
}

func (p *PartyModel) RemoveInvite(userID string) {
	for i, invite := range p.Invites {
		if invite.InviteeID == userID {
			p.Invites = append(p.Invites[:i], p.Invites[i+1:]...)
			return
		}
	}
}

func (p *PartyModel) Proto(users map[string]*UserModel) *pbapi.PartyState {
	members := make([]*pbapi.PartyMember, 0, len(p.Members))
	for _, member := range p.Members {
		user, ok := users[member.UserID]
		if !ok {
			continue
		}
		members = append(members, &pbapi.PartyMember{
			Player:   user.Proto(),
			JoinedAt: member.JoinedAt.Unix(),
		})
	}

	return &pbapi.PartyState{
		Id:        p.ID,
		LeaderId:  p.LeaderID,
		Members:   members,
		CreatedAt: p.CreatedAt.Unix(),
	}
}
