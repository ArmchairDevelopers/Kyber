package repository

import (
	"context"
	"errors"
	"time"

	"github.com/ArmchairDevelopers/Kyber/API/pkg/models"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

type SessionRepository interface {
	Upsert(ctx context.Context, session *models.SessionModel) error
	GetByUserID(ctx context.Context, userID string) (*models.SessionModel, error)
	GetByPartyID(ctx context.Context, partyID uint64) ([]models.SessionModel, error)
	Delete(ctx context.Context, userID string) error
	DeleteStale(ctx context.Context, maxAge time.Duration) ([]models.SessionModel, error)
	SetPartyID(ctx context.Context, userID string, partyID *uint64) error
	TouchMany(ctx context.Context, userIDs []string) error
	CountByPartyID(ctx context.Context, partyID uint64) (int64, error)
}

type mongoSessionRepo struct {
	col mongo.Collection
}

func NewSessionRepo(col *mongo.Collection) SessionRepository {
	return &mongoSessionRepo{col: *col}
}

func (r *mongoSessionRepo) Upsert(ctx context.Context, session *models.SessionModel) error {
	_, err := r.col.ReplaceOne(ctx, bson.M{"_id": session.UserID}, session, options.Replace().SetUpsert(true))
	return err
}

func (r *mongoSessionRepo) GetByUserID(ctx context.Context, userID string) (*models.SessionModel, error) {
	var session models.SessionModel
	err := r.col.FindOne(ctx, bson.M{"_id": userID}).Decode(&session)
	if err != nil {
		if errors.Is(err, mongo.ErrNoDocuments) {
			return nil, nil
		}
		return nil, err
	}
	return &session, nil
}

func (r *mongoSessionRepo) GetByPartyID(ctx context.Context, partyID uint64) ([]models.SessionModel, error) {
	cursor, err := r.col.Find(ctx, bson.M{"party_id": partyID})
	if err != nil {
		return nil, err
	}
	defer cursor.Close(ctx)

	var sessions []models.SessionModel
	if err := cursor.All(ctx, &sessions); err != nil {
		return nil, err
	}

	return sessions, nil
}

func (r *mongoSessionRepo) Delete(ctx context.Context, userID string) error {
	_, err := r.col.DeleteOne(ctx, bson.M{"_id": userID})
	return err
}

func (r *mongoSessionRepo) DeleteStale(ctx context.Context, maxAge time.Duration) ([]models.SessionModel, error) {
	cutoff := time.Now().Add(-maxAge)
	filter := bson.M{"updated_at": bson.M{"$lt": cutoff}}

	cursor, err := r.col.Find(ctx, filter)
	if err != nil {
		return nil, err
	}

	var stale []models.SessionModel
	if err := cursor.All(ctx, &stale); err != nil {
		return nil, err
	}

	if len(stale) == 0 {
		return nil, nil
	}

	ids := make([]string, len(stale))
	for i, s := range stale {
		ids[i] = s.UserID
	}

	_, err = r.col.DeleteMany(ctx, bson.M{"_id": bson.M{"$in": ids}})
	if err != nil {
		return nil, err
	}

	return stale, nil
}

func (r *mongoSessionRepo) SetPartyID(ctx context.Context, userID string, partyID *uint64) error {
	var update bson.M
	if partyID != nil {
		update = bson.M{"$set": bson.M{"party_id": *partyID}}
	} else {
		update = bson.M{"$unset": bson.M{"party_id": ""}}
	}

	_, err := r.col.UpdateOne(ctx, bson.M{"_id": userID}, update)
	return err
}

func (r *mongoSessionRepo) TouchMany(ctx context.Context, userIDs []string) error {
	if len(userIDs) == 0 {
		return nil
	}

	models := make([]mongo.WriteModel, len(userIDs))
	now := time.Now()
	for i, id := range userIDs {
		models[i] = mongo.NewUpdateOneModel().
			SetFilter(bson.M{"_id": id}).
			SetUpdate(bson.M{"$set": bson.M{"updated_at": now}})
	}

	_, err := r.col.BulkWrite(ctx, models, options.BulkWrite().SetOrdered(false))
	return err
}

func (r *mongoSessionRepo) CountByPartyID(ctx context.Context, partyID uint64) (int64, error) {
	return r.col.CountDocuments(ctx, bson.M{"party_id": partyID})
}
