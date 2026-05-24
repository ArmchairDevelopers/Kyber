package models

import (
	"sort"
	"time"

	"github.com/ArmchairDevelopers/Kyber/API/api/v1/pbapi"
	"github.com/ArmchairDevelopers/Kyber/API/api/v1/pbcommon"
)

type UserEntitlement string

const (
	EntitlementAdmin                   UserEntitlement = "ADMIN"
	EntitlementWhitelisted             UserEntitlement = "WHITELISTED"
	EntitlementGlobalServerModerator   UserEntitlement = "GLOBAL_SERVER_MODERATOR"
	EntitlementOfficialServerModerator UserEntitlement = "OFFICIAL_SERVER_MODERATOR"
	EntitlementStaff                   UserEntitlement = "STAFF"
	EntitlementDockerPush              UserEntitlement = "DOCKER_PUSH"
	EntitlementOfficialServers         UserEntitlement = "OFFICIAL_SERVERS"
	EntitlementVerifiedServers         UserEntitlement = "VERIFIED_SERVERS"
	EntitlementOfficialStats           UserEntitlement = "OFFICIAL_STATS"
	EntitlementPatreonPerks            UserEntitlement = "PATREON_PERKS"
	EntitlementDisableNameSync         UserEntitlement = "DISABLE_NAME_SYNC"
	EntitlementAutoApproveModImages    UserEntitlement = "AUTO_APPROVE_MOD_IMAGES"
	EntitlementBypassPlayerLimit       UserEntitlement = "BYPASS_PLAYER_LIMIT"
	EntitlementUnknown                 UserEntitlement = "UNKNOWN"
)

type EADeviceID struct {
	ID        string    `json:"id" bson:"id"`
	FirstSeen time.Time `json:"first_seen" bson:"first_seen"`
	LastSeen  time.Time `json:"last_seen" bson:"last_seen"`
}

type UserIP struct {
	IP        string    `json:"ip" bson:"ip"`
	FirstSeen time.Time `json:"first_seen" bson:"first_seen"`
	LastSeen  time.Time `json:"last_seen" bson:"last_seen"`
}

type EAUserData struct {
	DisplayName          string       `json:"display_name" bson:"display_name"`
	Nickname             string       `json:"nickname" bson:"nickname"`
	NameOnRegister       *string      `json:"name_on_register" bson:"name_on_register"`
	UserID               string       `json:"user_id" bson:"user_id"`
	PersonaID            string       `json:"persona_id" bson:"persona_id"`
	DeviceIDs            []EADeviceID `json:"device_ids" bson:"device_ids"`
	Country              string       `json:"country" bson:"country"`
	Language             string       `json:"language" bson:"language"`
	IsBanned             bool         `json:"is_banned" bson:"is_banned"`
	LastUpdated          *time.Time   `json:"last_updated" bson:"last_updated"`
	LastEntitlementCheck *time.Time   `json:"last_entitlement_check" bson:"last_entitlement_check"`
}

type UserMetricData struct {
	ServersHosted uint64 `json:"servers_hosted" bson:"servers_hosted"`
	ServersJoined uint64 `json:"servers_joined" bson:"servers_joined"`
	LoginCount    uint64 `json:"login_count" bson:"login_count"`
}

type PatreonData struct {
	ID           string    `json:"id" bson:"id"`
	MembershipID string    `json:"membership_id" bson:"membership_id"`
	LastChecked  time.Time `json:"last_checked" bson:"last_checked"`
	Email        string    `json:"email" bson:"email"`
	FullName     string    `json:"full_name" bson:"full_name"`
	DiscordID    *string   `json:"discord_id,omitempty" bson:"discord_id,omitempty"`
}

type DiscordData struct {
	ID            string    `json:"id" bson:"id"`
	Username      string    `json:"username" bson:"username"`
	Discriminator string    `json:"discriminator" bson:"discriminator"`
	AvatarHash    string    `json:"avatar_hash,omitempty" bson:"avatar_hash,omitempty"`
	GlobalName    string    `json:"global_name,omitempty" bson:"global_name,omitempty"`
	LastUpdated   time.Time `json:"last_updated" bson:"last_updated"`
}

type UserModel struct {
	ID               string            `json:"id" bson:"_id,omitempty"`
	Token            string            `json:"token" bson:"token"`
	Name             string            `json:"name" bson:"name"`
	Created          time.Time         `json:"created" bson:"created"`
	LastSeen         time.Time         `json:"last_seen" bson:"last_seen"`
	ModeratorUserIDs []string          `json:"moderator_user_ids" bson:"moderator_user_ids"`
	BannedUserIDs    []string          `json:"banned_user_ids" bson:"banned_user_ids"`
	Entitlements     []UserEntitlement `json:"entitlements" bson:"entitlements"`
	EAData           EAUserData        `json:"ea_data" bson:"ea_data"`
	IPs              []UserIP          `json:"ips" bson:"ips"`
	MetricData       UserMetricData    `json:"metric_data" bson:"metric_data"`
	PatreonData      *PatreonData      `json:"patreon_data,omitempty" bson:"patreon_data,omitempty"`
	DiscordData      *DiscordData      `json:"discord_data,omitempty" bson:"discord_data,omitempty"`
	VPNBlocked       bool              `json:"vpn_blocked" bson:"vpn_blocked"`
}

// IsPatron checks if the user has any patron-related entitlements. Either through the Patreon entitlement or having Patreon data associated with their account.
func (u *UserModel) IsPatron() bool {
	return u.Entitled(EntitlementPatreonPerks) || u.PatreonData != nil
}

func (u *UserModel) Proto() *pbcommon.KyberPlayer {
	return &pbcommon.KyberPlayer{
		Id:   u.ID,
		Name: u.Name,
	}
}

func (u *UserModel) ConvDiscordData() *pbapi.DiscordUserData {
	if u.DiscordData == nil {
		return nil
	}

	return &pbapi.DiscordUserData{
		Id:            u.DiscordData.ID,
		Username:      u.DiscordData.Username,
		Discriminator: u.DiscordData.Discriminator,
		AvatarHash:    u.DiscordData.AvatarHash,
		GlobalName:    u.DiscordData.GlobalName,
	}
}

func (u *UserModel) ConvEntitlements() []string {
	entitlements := make([]string, len(u.Entitlements))
	for i, entitlement := range u.Entitlements {
		entitlements[i] = string(entitlement)
	}
	return entitlements
}

func (u *UserModel) Entitled(e UserEntitlement) bool {
	for _, ent := range u.Entitlements {
		if ent == e {
			return true
		}
	}
	return false
}

func (u *UserModel) UpsertIP(ip string) {
	now := time.Now()
	for i := range u.IPs {
		if u.IPs[i].IP == ip {
			u.IPs[i].LastSeen = now
			return
		}
	}

	u.IPs = append(u.IPs, UserIP{
		IP:        ip,
		FirstSeen: now,
		LastSeen:  now,
	})
}

func (u *UserModel) PruneIPs(max int) {
	sort.Slice(u.IPs, func(i, j int) bool {
		return u.IPs[i].LastSeen.After(u.IPs[j].LastSeen)
	})

	if len(u.IPs) > max {
		u.IPs = u.IPs[:max]
	}
}

func (u *UserModel) GetServerLimit() int {
	switch {
	case u.Entitled(EntitlementOfficialServers):
		return 100
	case u.Entitled(EntitlementVerifiedServers):
		return 6
	case u.IsPatron():
		return 4
	default:
		return 2
	}
}

func (d *EAUserData) UpsertDevice(dvid string) {
	now := time.Now()
	for i := range d.DeviceIDs {
		if d.DeviceIDs[i].ID == dvid {
			d.DeviceIDs[i].LastSeen = now
			return
		}
	}

	d.DeviceIDs = append(d.DeviceIDs, EADeviceID{
		ID:        dvid,
		FirstSeen: now,
		LastSeen:  now,
	})
}
