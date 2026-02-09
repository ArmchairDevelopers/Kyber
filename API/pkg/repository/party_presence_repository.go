package repository

import (
	"context"
	"time"

	"github.com/ArmchairDevelopers/Kyber/API/pkg/models"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

type PresenceRepository interface {
	Upsert(ctx context.Context, userID string) error
	UpsertMany(ctx context.Context, userIDs []string) error
	Delete(ctx context.Context, userID string) error
	FindExisting(ctx context.Context, userIDs []string) ([]string, error)
}

type mongoPresenceRepo struct {
	col mongo.Collection
}

func NewPresenceRepo(col *mongo.Collection) PresenceRepository {
	return &mongoPresenceRepo{col: *col}
}

func (r *mongoPresenceRepo) Upsert(ctx context.Context, userID string) error {
	_, err := r.col.UpdateOne(ctx,
		bson.M{"_id": userID},
		bson.M{"$set": bson.M{"updated_at": time.Now()}},
		options.Update().SetUpsert(true),
	)
	return err
}

func (r *mongoPresenceRepo) UpsertMany(ctx context.Context, userIDs []string) error {
	if len(userIDs) == 0 {
		return nil
	}

	models := make([]mongo.WriteModel, len(userIDs))
	now := time.Now()
	for i, id := range userIDs {
		models[i] = mongo.NewUpdateOneModel().
			SetFilter(bson.M{"_id": id}).
			SetUpdate(bson.M{"$set": bson.M{"updated_at": now}}).
			SetUpsert(true)
	}

	_, err := r.col.BulkWrite(ctx, models, options.BulkWrite().SetOrdered(false))
	return err
}

func (r *mongoPresenceRepo) Delete(ctx context.Context, userID string) error {
	_, err := r.col.DeleteOne(ctx, bson.M{"_id": userID})
	return err
}

func (r *mongoPresenceRepo) FindExisting(ctx context.Context, userIDs []string) ([]string, error) {
	if len(userIDs) == 0 {
		return nil, nil
	}

	cursor, err := r.col.Find(ctx, bson.M{"_id": bson.M{"$in": userIDs}}, options.Find().SetProjection(bson.M{"_id": 1}))
	if err != nil {
		return nil, err
	}
	defer cursor.Close(ctx)

	var results []models.PartyPresenceModel
	if err := cursor.All(ctx, &results); err != nil {
		return nil, err
	}

	existing := make([]string, len(results))
	for i, r := range results {
		existing[i] = r.UserID
	}
	return existing, nil
}
