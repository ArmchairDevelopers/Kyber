package repository

import (
	"context"
	"errors"
	"time"

	"github.com/ArmchairDevelopers/Kyber/API/pkg/models"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
)

type PunishmentRepository interface {
	GetForUser(ctx context.Context, userID string) ([]*models.PunishmentModel, error)
	GetGlobalBan(ctx context.Context, userID string) (*models.PunishmentModel, error)
	GetBanForServer(ctx context.Context, hostID string, userID string) (*models.PunishmentModel, error)
	Create(ctx context.Context, punishment *models.PunishmentModel) error
	Update(ctx context.Context, punishment *models.PunishmentModel) error
	UpdateDoc(ctx context.Context, id string, m bson.M) error
	SearchForBan(ctx context.Context, ip string, deviceIDs []string) (*models.PunishmentModel, error)
	GetBansForServer(ctx context.Context, hostID string) ([]*models.PunishmentModel, error)
}

type mongoPunishmentRepo struct {
	col mongo.Collection
}

func NewPunishmentRepo(col *mongo.Collection) PunishmentRepository {
	return &mongoPunishmentRepo{col: *col}
}

func (r *mongoPunishmentRepo) GetForUser(ctx context.Context, userID string) ([]*models.PunishmentModel, error) {
	pipeline := mongo.Pipeline{
		{{Key: "$match", Value: bson.M{"user": userID}}},
		{{Key: "$lookup", Value: bson.M{
			"from":         "users",
			"localField":   "user",
			"foreignField": "_id",
			"as":           "user_model",
		}}},
		{{Key: "$unwind", Value: bson.M{
			"path":                       "$user_model",
			"preserveNullAndEmptyArrays": true,
		}}},

		{{Key: "$lookup", Value: bson.M{
			"from":         "users",
			"localField":   "moderator_id",
			"foreignField": "_id",
			"as":           "moderator_model",
		}}},
		{{Key: "$unwind", Value: bson.M{
			"path":                       "$moderator_model",
			"preserveNullAndEmptyArrays": true,
		}}},
	}

	cursor, err := r.col.Aggregate(ctx, pipeline)
	if err != nil {
		return nil, err
	}
	defer cursor.Close(ctx)

	var result []*models.PunishmentModel
	if err := cursor.All(ctx, &result); err != nil {
		return nil, err
	}

	return result, nil
}

func (r *mongoPunishmentRepo) UpdateDoc(ctx context.Context, id string, m bson.M) error {
	_, err := r.col.UpdateOne(ctx, bson.M{"_id": id}, m)

	return err
}
func (r *mongoPunishmentRepo) SearchForBan(ctx context.Context, ip string, deviceIDs []string) (*models.PunishmentModel, error) {
	var result models.PunishmentModel
	err := r.col.FindOne(ctx, bson.M{
		"$and": []bson.M{
			{"issuer": nil},
			{"type": models.PunishmentTypeBan},
			{"overturned_by": nil},
			{"$and": []bson.M{
				{
					"$or": []bson.M{
						{"expires_at": nil},
						{"expires_at": bson.M{"$gt": time.Now()}},
					},
				},
			}},
			{"$or": []bson.M{
				{"device_ids": bson.M{"$in": deviceIDs}},
				{"last_used_ip": ip},
			}},
		},
	}).Decode(&result)

	if err != nil {
		if errors.Is(err, mongo.ErrNoDocuments) {
			return nil, nil
		}

		return nil, err
	}

	return &result, nil
}

func (r *mongoPunishmentRepo) GetBansForServer(ctx context.Context, hostID string) ([]*models.PunishmentModel, error) {
	var result []*models.PunishmentModel
	cursor, err := r.col.Find(ctx, bson.M{"issuer": hostID, "type": models.PunishmentTypeBan})
	if err != nil {
		return nil, err
	}

	defer cursor.Close(ctx)

	for cursor.Next(ctx) {
		var punishment models.PunishmentModel
		err := cursor.Decode(&punishment)
		if err != nil {
			return nil, err
		}

		result = append(result, &punishment)
	}

	if err := cursor.Err(); err != nil {
		return nil, err
	}

	return result, nil
}

func (r *mongoPunishmentRepo) Create(ctx context.Context, punishment *models.PunishmentModel) error {
	_, err := r.col.InsertOne(ctx, punishment)
	if err != nil {
		return err
	}

	return nil
}

func (r *mongoPunishmentRepo) Update(ctx context.Context, punishment *models.PunishmentModel) error {
	_, err := r.col.UpdateOne(ctx, bson.M{"_id": punishment.ID}, bson.M{"$set": punishment})

	return err
}

func (r *mongoPunishmentRepo) GetBanForServer(ctx context.Context, hostID string, userID string) (*models.PunishmentModel, error) {
	var result models.PunishmentModel
	err := r.col.FindOne(ctx, bson.M{
		"user":          userID,
		"type":          models.PunishmentTypeBan,
		"issuer":        hostID,
		"overturned_by": nil,
		"$and": []bson.M{
			{
				"$or": []bson.M{
					{"expires_at": nil},
					{"expires_at": bson.M{"$gt": time.Now()}},
				},
			},
		},
	}).Decode(&result)
	if err != nil {
		if errors.Is(err, mongo.ErrNoDocuments) {
			return nil, nil
		}

		return nil, err
	}

	return &result, nil
}

func (r *mongoPunishmentRepo) GetGlobalBan(ctx context.Context, userID string) (*models.PunishmentModel, error) {
	var result models.PunishmentModel
	err := r.col.FindOne(ctx, bson.M{
		"user":          userID,
		"type":          models.PunishmentTypeBan,
		"issuer":        nil,
		"overturned_by": nil,
		"$and": []bson.M{
			{
				"$or": []bson.M{
					{"expires_at": nil},
					{"expires_at": bson.M{"$gt": time.Now()}},
				},
			},
		},
	}).Decode(&result)
	if err != nil {
		if errors.Is(err, mongo.ErrNoDocuments) {
			return nil, nil
		}

		return nil, err
	}

	return &result, nil
}
