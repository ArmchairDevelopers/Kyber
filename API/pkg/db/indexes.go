package db

import (
	"context"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
	"go.uber.org/zap"
)

func setupIndexes(ctx context.Context, client *mongo.Client) {
	db := client.Database("kyber")

	userIdx := mongo.IndexModel{
		Keys: bson.D{
			{Key: "patreon_data", Value: 1},
			{Key: "patreon_data.discord_id", Value: 1},
			{Key: "name", Value: 1},
		},
		Options: options.Index().SetName("patreon_and_name_idx"),
	}
	if _, err := db.Collection("users").Indexes().CreateOne(ctx, userIdx); err != nil {
		zap.L().Error("failed to create users index", zap.Error(err))
	}

	discordIdx := mongo.IndexModel{
		Keys:    bson.D{{Key: "discord_id", Value: 1}},
		Options: options.Index().SetName("discord_id_idx"),
	}
	if _, err := db.Collection("users").Indexes().CreateOne(ctx, discordIdx); err != nil {
		zap.L().Error("failed to create discord_id index", zap.Error(err))
	}

	punIssuerIdx := mongo.IndexModel{
		Keys:    bson.D{{Key: "issuer", Value: 1}},
		Options: options.Index().SetName("issuer_idx"),
	}
	if _, err := db.Collection("punishments").Indexes().CreateOne(ctx, punIssuerIdx); err != nil {
		zap.L().Error("failed to create punishments.issuer index", zap.Error(err))
	}

	punUserIdx := mongo.IndexModel{
		Keys:    bson.D{{Key: "user", Value: 1}},
		Options: options.Index().SetName("user_idx"),
	}
	if _, err := db.Collection("punishments").Indexes().CreateOne(ctx, punUserIdx); err != nil {
		zap.L().Error("failed to create punishments.user index", zap.Error(err))
	}

	srvIdx := mongo.IndexModel{
		Keys: bson.D{
			{Key: "host_token", Value: 1},
			{Key: "last_updated", Value: 1},
		},
		Options: options.Index().SetName("host_token_updated_idx"),
	}
	if _, err := db.Collection("servers").Indexes().CreateOne(ctx, srvIdx); err != nil {
		zap.L().Error("failed to create servers index", zap.Error(err))
	}

	jtTTLIdx := mongo.IndexModel{
		Keys: bson.D{{Key: "created", Value: 1}},
		Options: options.Index().
			SetName("created_ttl_idx").
			SetExpireAfterSeconds(15 * 60),
	}
	if _, err := db.Collection("join_tokens").Indexes().CreateOne(ctx, jtTTLIdx); err != nil {
		zap.L().Error("failed to create servers TTL index", zap.Error(err))
	}

	ptiTTLIdx := mongo.IndexModel{
		Keys: bson.D{{Key: "created_at", Value: 1}},
		Options: options.Index().
			SetName("created_ttl_idx").
			SetExpireAfterSeconds(60),
	}
	if _, err := db.Collection("party_invites").Indexes().CreateOne(ctx, ptiTTLIdx); err != nil {
		zap.L().Error("failed to create party_invites TTL index", zap.Error(err))
	}

	imageHashIdx := mongo.IndexModel{
		Keys:    bson.D{{Key: "hash", Value: 1}},
		Options: options.Index().SetName("hash_idx"),
	}
	if _, err := db.Collection("image_hashes").Indexes().CreateOne(ctx, imageHashIdx); err != nil {
		zap.L().Error("failed to create image hashes index", zap.Error(err))
	}

	modUserIdx := mongo.IndexModel{
		Keys:    bson.D{{Key: "moderator_user_ids", Value: 1}},
		Options: options.Index().SetName("moderator_user_ids_idx"),
	}
	if _, err := db.Collection("users").Indexes().CreateOne(ctx, modUserIdx); err != nil {
		zap.L().Error("failed to create users.moderator_user_ids index", zap.Error(err))
	}

	hostIDIdx := mongo.IndexModel{
		Keys:    bson.D{{Key: "host_id", Value: 1}},
		Options: options.Index().SetName("host_id_idx"),
	}
	if _, err := db.Collection("servers").Indexes().CreateOne(ctx, hostIDIdx); err != nil {
		zap.L().Error("failed to create servers.host_id index", zap.Error(err))
	}

	sessionUpdatedIdx := mongo.IndexModel{
		Keys:    bson.D{{Key: "updated_at", Value: 1}},
		Options: options.Index().SetName("updated_at_idx"),
	}
	if _, err := db.Collection("sessions").Indexes().CreateOne(ctx, sessionUpdatedIdx); err != nil {
		zap.L().Error("failed to create sessions updated_at index", zap.Error(err))
	}

	sessionPartyIdx := mongo.IndexModel{
		Keys:    bson.D{{Key: "party_id", Value: 1}},
		Options: options.Index().SetName("party_id_idx"),
	}
	if _, err := db.Collection("sessions").Indexes().CreateOne(ctx, sessionPartyIdx); err != nil {
		zap.L().Error("failed to create sessions party_id index", zap.Error(err))
	}

	// TODO: create indexes for hosted mods
}
