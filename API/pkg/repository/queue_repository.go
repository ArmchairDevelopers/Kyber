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

type QueueRepository interface {
	Create(ctx context.Context, entry *models.QueueEntryModel) error
	GetByID(ctx context.Context, id string) (*models.QueueEntryModel, error)
	GetByUserID(ctx context.Context, userID string) (*models.QueueEntryModel, error)
	GetByPartyID(ctx context.Context, partyID uint64) (*models.QueueEntryModel, error)
	GetWaitingByServer(ctx context.Context, serverID string) ([]*models.QueueEntryModel, error)
	GetReservedByServer(ctx context.Context, serverID string) ([]*models.QueueEntryModel, error)
	GetReservedForUser(ctx context.Context, serverID string, userID string) (*models.QueueEntryModel, error)
	GetByServerIDs(ctx context.Context, serverIDs []string) ([]*models.QueueEntryModel, error)
	GetAll(ctx context.Context) ([]*models.QueueEntryModel, error)
	HasWaitingOrReserved(ctx context.Context, serverID string, now time.Time) (bool, error)
	MarkReserved(ctx context.Context, id string, memberIDs []string, expiresAt time.Time) (bool, error)
	AddClaimedTokenID(ctx context.Context, id string, userID string) (*models.QueueEntryModel, error)
	Delete(ctx context.Context, id string) (bool, error)
	AcquireServerLock(ctx context.Context, key string, owner string, ttl time.Duration) (bool, error)
	ReleaseServerLock(ctx context.Context, key string, owner string) error
}

type mongoQueueRepo struct {
	col     mongo.Collection
	lockCol mongo.Collection
}

func NewQueueRepo(col *mongo.Collection, lockCol *mongo.Collection) QueueRepository {
	return &mongoQueueRepo{col: *col, lockCol: *lockCol}
}

func (r *mongoQueueRepo) Create(ctx context.Context, entry *models.QueueEntryModel) error {
	_, err := r.col.InsertOne(ctx, entry)
	return err
}

func (r *mongoQueueRepo) GetByID(ctx context.Context, id string) (*models.QueueEntryModel, error) {
	return r.findOne(ctx, bson.M{"_id": id})
}

func (r *mongoQueueRepo) GetByUserID(ctx context.Context, userID string) (*models.QueueEntryModel, error) {
	return r.findOne(ctx, bson.M{"user_id": userID})
}

func (r *mongoQueueRepo) GetByPartyID(ctx context.Context, partyID uint64) (*models.QueueEntryModel, error) {
	return r.findOne(ctx, bson.M{"party_id": partyID})
}

func (r *mongoQueueRepo) GetWaitingByServer(ctx context.Context, serverID string) ([]*models.QueueEntryModel, error) {
	return r.find(ctx, bson.M{
		"server_id": serverID,
		"state":     models.QueueEntryStateWaiting,
	}, options.Find().SetSort(bson.D{{Key: "enqueued_at", Value: 1}}))
}

func (r *mongoQueueRepo) GetReservedByServer(ctx context.Context, serverID string) ([]*models.QueueEntryModel, error) {
	return r.find(ctx, bson.M{
		"server_id": serverID,
		"state":     models.QueueEntryStateReserved,
	}, options.Find())
}

func (r *mongoQueueRepo) GetReservedForUser(ctx context.Context, serverID string, userID string) (*models.QueueEntryModel, error) {
	return r.findOne(ctx, bson.M{
		"server_id":              serverID,
		"state":                  models.QueueEntryStateReserved,
		"reservation_expires_at": bson.M{"$gt": time.Now()},
		"$or": bson.A{
			bson.M{"user_id": userID},
			bson.M{"member_ids": userID},
		},
	})
}

func (r *mongoQueueRepo) GetByServerIDs(ctx context.Context, serverIDs []string) ([]*models.QueueEntryModel, error) {
	return r.find(ctx, bson.M{"server_id": bson.M{"$in": serverIDs}}, options.Find())
}

func (r *mongoQueueRepo) GetAll(ctx context.Context) ([]*models.QueueEntryModel, error) {
	return r.find(ctx, bson.M{}, options.Find())
}

func (r *mongoQueueRepo) HasWaitingOrReserved(ctx context.Context, serverID string, now time.Time) (bool, error) {
	count, err := r.col.CountDocuments(ctx, bson.M{
		"server_id": serverID,
		"$or": bson.A{
			bson.M{"state": models.QueueEntryStateWaiting},
			bson.M{
				"state":                  models.QueueEntryStateReserved,
				"reservation_expires_at": bson.M{"$gt": now},
			},
		},
	}, options.Count().SetLimit(1))
	if err != nil {
		return false, err
	}

	return count > 0, nil
}

func (r *mongoQueueRepo) MarkReserved(ctx context.Context, id string, memberIDs []string, expiresAt time.Time) (bool, error) {
	res, err := r.col.UpdateOne(ctx, bson.M{
		"_id":   id,
		"state": models.QueueEntryStateWaiting,
	}, bson.M{
		"$set": bson.M{
			"state":                  models.QueueEntryStateReserved,
			"reservation_expires_at": expiresAt,
			"member_ids":             memberIDs,
			"claimed_ids":            bson.A{},
		},
	})
	if err != nil {
		return false, err
	}

	return res.ModifiedCount == 1, nil
}

func (r *mongoQueueRepo) AddClaimedTokenID(ctx context.Context, id string, userID string) (*models.QueueEntryModel, error) {
	var entry models.QueueEntryModel
	err := r.col.FindOneAndUpdate(ctx, bson.M{
		"_id":   id,
		"state": models.QueueEntryStateReserved,
	}, bson.M{
		"$addToSet": bson.M{"claimed_ids": userID},
	}, options.FindOneAndUpdate().SetReturnDocument(options.After)).Decode(&entry)
	if err != nil {
		if errors.Is(err, mongo.ErrNoDocuments) {
			return nil, nil
		}
		return nil, err
	}

	return &entry, nil
}

func (r *mongoQueueRepo) Delete(ctx context.Context, id string) (bool, error) {
	res, err := r.col.DeleteOne(ctx, bson.M{"_id": id})
	if err != nil {
		return false, err
	}

	return res.DeletedCount == 1, nil
}

func (r *mongoQueueRepo) AcquireServerLock(ctx context.Context, key string, owner string, ttl time.Duration) (bool, error) {
	now := time.Now()
	_, err := r.lockCol.UpdateOne(ctx, bson.M{
		"_id":        key,
		"expires_at": bson.M{"$lt": now},
	}, bson.M{
		"$set": bson.M{
			"expires_at": now.Add(ttl),
			"owner":      owner,
		},
	}, options.Update().SetUpsert(true))
	if err != nil {
		if mongo.IsDuplicateKeyError(err) {
			return false, nil
		}

		return false, err
	}

	return true, nil
}

func (r *mongoQueueRepo) ReleaseServerLock(ctx context.Context, key string, owner string) error {
	_, err := r.lockCol.DeleteOne(ctx, bson.M{"_id": key, "owner": owner})
	return err
}

func (r *mongoQueueRepo) findOne(ctx context.Context, filter bson.M) (*models.QueueEntryModel, error) {
	var entry models.QueueEntryModel
	err := r.col.FindOne(ctx, filter).Decode(&entry)
	if err != nil {
		if errors.Is(err, mongo.ErrNoDocuments) {
			return nil, nil
		}
		return nil, err
	}

	return &entry, nil
}

func (r *mongoQueueRepo) find(ctx context.Context, filter bson.M, opts *options.FindOptions) ([]*models.QueueEntryModel, error) {
	cursor, err := r.col.Find(ctx, filter, opts)
	if err != nil {
		return nil, err
	}

	defer cursor.Close(ctx)

	var entries []*models.QueueEntryModel
	for cursor.Next(ctx) {
		var entry models.QueueEntryModel
		if err := cursor.Decode(&entry); err != nil {
			return nil, err
		}

		entries = append(entries, &entry)
	}

	if err := cursor.Err(); err != nil {
		return nil, err
	}

	return entries, nil
}
