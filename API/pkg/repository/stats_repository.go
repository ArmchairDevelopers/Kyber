package repository

import (
	"context"
	"errors"
	"fmt"

	"github.com/ArmchairDevelopers/Kyber/API/pkg/models"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
)

type StatsRepository interface {
	Upsert(ctx context.Context, ownerID string, userID string, source models.StatsSource, stats models.UserStats) error
	Get(ctx context.Context, userID string, source string) (*models.UserStatsModel, error)
}

type mongoStatsRepo struct {
	col mongo.Collection
}

func NewStatsRepo(col *mongo.Collection) StatsRepository {
	return &mongoStatsRepo{col: *col}
}

func (r *mongoStatsRepo) Get(ctx context.Context, userID string, source string) (*models.UserStatsModel, error) {
	// TODO: implement personal stats retrieval
	id := r.getDBKey("", userID, models.StatsSource(source))

	var result models.UserStatsModel
	err := r.col.FindOne(ctx, bson.M{"_id": id}).Decode(&result)
	if err != nil {
		if errors.Is(err, mongo.ErrNoDocuments) {
			return nil, nil
		}

		return nil, err
	}

	return &result, nil
}

func (r *mongoStatsRepo) Upsert(ctx context.Context, ownerID string, userID string, source models.StatsSource, stats models.UserStats) error {
	if source != models.StatsSourceKyber && source != models.StatsSourcePersonal {
		return fmt.Errorf("invalid stats source: %s", source)
	}

	model := &models.UserStatsModel{
		UserID: userID,
		Source: source,
		Stats:  stats,
	}

	id := r.getDBKey(ownerID, userID, source)
	_, err := r.col.UpdateOne(ctx, bson.M{"_id": id}, bson.M{"$set": model}, options.UpdateOne().SetUpsert(true))

	return err
}

func (r *mongoStatsRepo) getDBKey(ownerID string, userID string, source models.StatsSource) string {
	if source == models.StatsSourceKyber {
		return fmt.Sprintf("%s-%s", string(models.StatsSourceKyber), userID)
	}

	return fmt.Sprintf("%s-%s", ownerID, userID)
}
