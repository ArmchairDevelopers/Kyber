package models

import (
	"time"

	"github.com/ArmchairDevelopers/Kyber/API/api/v1/pbapi"
	"github.com/ArmchairDevelopers/Kyber/API/api/v1/pbcommon"
)

type PartyJoinGameMemberStatus struct {
	UserID                string  `json:"user_id" bson:"user_id"`
	HasMods               bool    `json:"has_mods" bson:"has_mods"`
	ModDownloadPercentage *uint32 `json:"mod_download_percentage,omitempty" bson:"mod_download_percentage,omitempty"`
}

type PartyJoinGameState struct {
	ServerID       string                      `json:"server_id" bson:"server_id"`
	ServerName     string                      `json:"server_name" bson:"server_name"`
	Mods           []ServerModModel            `json:"mods" bson:"mods"`
	MemberStatuses []PartyJoinGameMemberStatus `json:"member_statuses,omitempty" bson:"member_statuses,omitempty"`
}

type PartyModel struct {
	ID            uint64              `json:"id" bson:"_id"`
	LeaderID      string              `json:"leader_id" bson:"leader_id"`
	CreatedAt     time.Time           `json:"created_at" bson:"created_at"`
	JoinGameState *PartyJoinGameState `json:"join_game_state,omitempty" bson:"join_game_state,omitempty"`
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

	state := &pbapi.PartyState{
		Id:        p.ID,
		LeaderId:  p.LeaderID,
		Members:   members,
		CreatedAt: p.CreatedAt.Unix(),
	}

	if p.JoinGameState != nil {
		mods := make([]*pbcommon.ServerMod, len(p.JoinGameState.Mods))
		for i, mod := range p.JoinGameState.Mods {
			mods[i] = &pbcommon.ServerMod{
				Name:     mod.Name,
				Version:  mod.Version,
				Link:     mod.Link,
				FileSize: mod.FileSize,
			}
		}

		statuses := make([]*pbapi.JoinGameMemberStatus, len(p.JoinGameState.MemberStatuses))
		for i, st := range p.JoinGameState.MemberStatuses {
			statuses[i] = &pbapi.JoinGameMemberStatus{
				UserId:                st.UserID,
				HasMods:               st.HasMods,
				ModDownloadPercentage: st.ModDownloadPercentage,
			}
		}

		state.JoinGameState = &pbapi.JoinGameState{
			ServerId:       p.JoinGameState.ServerID,
			ServerName:     p.JoinGameState.ServerName,
			Mods:           mods,
			MemberStatuses: statuses,
		}
	}

	return state
}
