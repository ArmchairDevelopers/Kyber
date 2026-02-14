package db

import (
	"context"

	"github.com/ArmchairDevelopers/Kyber/API/pkg/repository"
)

type Store struct {
	Users        repository.UserRepository
	Servers      repository.ServerRepository
	JoinTokens   repository.JoinTokenRepository
	Punishments  repository.PunishmentRepository
	HostedMods   repository.HostedModRepository
	Stats        repository.StatsRepository
	Reports      repository.ReportRepository
	ModImages    repository.ModImageRepository
	Parties      repository.PartyRepository
	PartyInvites repository.PartyInviteRepository
	Sessions     repository.SessionRepository
}

func NewStore(ctx context.Context, uri string) (*Store, error) {
	client, err := Connect(uri)
	if err != nil {
		return nil, err
	}

	setupIndexes(ctx, client)

	userCollection := GetCollection("kyber", "users")
	serverCollection := GetCollection("kyber", "servers")
	joinTokenCollection := GetCollection("kyber", "join_tokens")
	punishmentCollection := GetCollection("kyber", "punishments")
	hostedModCollection := GetCollection("kyber", "hosted_mods")
	statsCollection := GetCollection("kyber", "user_stats")
	reportCollection := GetCollection("kyber", "reports")
	modImageCollection := GetCollection("kyber", "mod_images")
	partyCollection := GetCollection("kyber", "parties")
	partyInviteCollection := GetCollection("kyber", "party_invites")
	sessionCollection := GetCollection("kyber", "sessions")

	return &Store{
		Users:        repository.NewUserRepo(userCollection),
		Servers:      repository.NewServerRepository(serverCollection),
		JoinTokens:   repository.NewJoinTokenRepo(joinTokenCollection),
		Punishments:  repository.NewPunishmentRepo(punishmentCollection),
		HostedMods:   repository.NewHostedModRepo(hostedModCollection),
		Stats:        repository.NewStatsRepo(statsCollection),
		Reports:      repository.NewReportRepo(reportCollection),
		ModImages:    repository.NewModImageRepo(modImageCollection),
		Parties:      repository.NewPartyRepo(partyCollection),
		PartyInvites: repository.NewPartyInviteRepo(partyInviteCollection),
		Sessions:     repository.NewSessionRepo(sessionCollection),
	}, nil
}
