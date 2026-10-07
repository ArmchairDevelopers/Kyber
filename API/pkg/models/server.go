package models

import (
	"slices"
	"time"

	"github.com/ArmchairDevelopers/Kyber/API/api/v1/pbapi"
	"github.com/ArmchairDevelopers/Kyber/API/api/v1/pbcommon"
	goaway "github.com/TwiN/go-away"
	"github.com/go-playground/validator/v10"
	"github.com/golang-jwt/jwt/v5"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

type ServerJWT struct {
	UserID   string `json:"user_id"`
	ServerID string `json:"server_id"`
	jwt.RegisteredClaims
}

type KronosServerUpdate struct {
	ServerCreated  *ServerModel `json:"server_created"`
	ServerUpdated  *ServerModel `json:"server_updated"`
	ServersDeleted []*string    `json:"servers_deleted"`
}

type LevelSetupModel struct {
	Map       string  `json:"map" bson:"map"`
	Mode      string  `json:"mode" bson:"mode"`
	MapName   *string `json:"map_name,omitempty" bson:"map_name,omitempty" validate:"omitempty,max=40"`
	ModeName  *string `json:"mode_name,omitempty" bson:"mode_name,omitempty" validate:"omitempty,max=60"`
	ImageHash *string `json:"image_hash,omitempty" bson:"image_hash,omitempty"`
}

type NetworkAddress struct {
	IP   string `json:"ip" bson:"ip"`
	Port int    `json:"port" bson:"port"`
}

type ServerModModel struct {
	Name     string  `json:"name" bson:"name"`
	Version  string  `json:"version" bson:"version"`
	Link     *string `json:"link" bson:"link"`
	FileSize uint64  `json:"file_size" bson:"file_size"`
}

type ServerModel struct {
	ID             string            `json:"id" bson:"_id,omitempty"`
	Name           string            `json:"name" bson:"name" validate:"required,max=40,min=3"`
	Password       *string           `json:"password,omitempty" bson:"password,omitempty" validate:"omitempty,max=64"`
	Description    *string           `json:"description,omitempty" bson:"description,omitempty" validate:"omitempty,max=256"`
	LevelSetup     LevelSetupModel   `json:"level_setup" bson:"level_setup" validate:"required"`
	Dedicated      bool              `json:"dedicated" bson:"dedicated"`
	Host           string            `json:"host" bson:"host"`
	HostID         string            `json:"host_id" bson:"host_id"`
	HostAddress    NetworkAddress    `json:"host_address" bson:"host_address"`
	Mods           []ServerModModel  `json:"mods" bson:"mods"`
	ExplodedMods   []ServerModModel  `json:"exploded_mods" bson:"exploded_mods"`
	MetaData       map[string]string `json:"meta_data" bson:"meta_data"`
	PlayerCount    uint32            `json:"player_count" bson:"player_count"`
	ConnectedCount uint32            `json:"connected_count" bson:"connected_count"`
	MaxPlayerCount uint32            `json:"max_player_count" bson:"max_player_count" validate:"required,min=1,max=64"`
	Official       bool              `json:"official" bson:"official"`
	Verified       bool              `json:"verified" bson:"verified"`
	HostToken      string            `json:"host_token" bson:"host_token"`
	HostRegion     *string           `json:"host_region" bson:"host_region,omitempty"`
	LastUpdated    time.Time         `json:"last_updated" bson:"last_updated"`
	ProxyToken     string            `json:"proxy_token" bson:"proxy_token"`
}

func (server *ServerModel) Proto() *pbapi.Server {
	mods := make([]*pbcommon.ServerMod, len(server.Mods))
	for i, mod := range server.Mods {
		mods[i] = &pbcommon.ServerMod{
			Name:     mod.Name,
			Version:  mod.Version,
			Link:     mod.Link,
			FileSize: mod.FileSize,
		}
	}

	return &pbapi.Server{
		Name:        server.Name,
		Description: server.Description,
		LevelSetup: &pbcommon.LevelSetup{
			Mode:     server.LevelSetup.Mode,
			Map:      server.LevelSetup.Map,
			ModeName: server.LevelSetup.ModeName,
			MapName:  server.LevelSetup.MapName,
		},
		PlayerCount:      server.PlayerCount,
		MaxPlayerCount:   server.MaxPlayerCount,
		Official:         server.Official,
		Port:             nil,
		Mods:             mods,
		Id:               server.ID,
		Ip:               nil,
		Meta:             server.MetaData,
		Creator:          server.Host,
		CreatorId:        server.HostID,
		RequiresPassword: server.Password != nil && len(*server.Password) > 0,
		RequiresProxy:    true,
		Region:           server.HostRegion,
		MapImageHash:     server.LevelSetup.ImageHash,
	}
}

func (server *ServerModel) Validate() error {
	if goaway.IsProfane(server.Name) {
		return status.Error(codes.InvalidArgument, "Server name contains profane words")
	}

	if server.Description != nil && goaway.IsProfane(*server.Description) {
		return status.Error(codes.InvalidArgument, "Server description contains profane words")
	}

	if server.LevelSetup.MapName != nil && goaway.IsProfane(*server.LevelSetup.MapName) {
		return status.Error(codes.InvalidArgument, "Level setup map name contains profane words")
	}

	if server.LevelSetup.ModeName != nil && goaway.IsProfane(*server.LevelSetup.ModeName) {
		return status.Error(codes.InvalidArgument, "Level setup mode name contains profane words")
	}

	return validator.New().Struct(server)
}

func (server *ServerModel) CanManage(host *UserModel, user *UserModel) bool {
	if user == nil || server == nil {
		return false
	}

	if !user.Entitled(EntitlementGlobalServerModerator) &&
		user.ID != server.HostID &&
		!slices.Contains(host.ModeratorUserIDs, user.ID) {
		return false
	}

	return true
}
