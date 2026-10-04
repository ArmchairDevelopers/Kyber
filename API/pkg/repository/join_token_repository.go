package repository

import (
	"context"
	"errors"

	"github.com/ArmchairDevelopers/Kyber/API/pkg/models"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
)

type JoinTokenRepository interface {
	Create(ctx context.Context, token *models.JoinTokenModel) error
	GetByToken(ctx context.Context, token string) (*models.JoinTokenModel, error)
	GetByUserID(ctx context.Context, userID string) ([]*models.JoinTokenModel, error)
	GetByServerID(ctx context.Context, serverID string) ([]*models.JoinTokenModel, error)
	DeleteByToken(ctx context.Context, token string) error
}

type mongoJoinTokenRepo struct {
	col mongo.Collection
}

func NewJoinTokenRepo(col *mongo.Collection) JoinTokenRepository {
	return &mongoJoinTokenRepo{col: *col}
}

func (r *mongoJoinTokenRepo) GetByServerID(ctx context.Context, serverID string) ([]*models.JoinTokenModel, error) {
	var result []*models.JoinTokenModel
	cursor, err := r.col.Find(ctx, bson.M{"server": serverID})
	if err != nil {
		return nil, err
	}

	defer cursor.Close(ctx)

	for cursor.Next(ctx) {
		var token models.JoinTokenModel
		err := cursor.Decode(&token)
		if err != nil {
			return nil, err
		}

		result = append(result, &token)
	}

	if err := cursor.Err(); err != nil {
		return nil, err
	}

	return result, nil
}

func (r *mongoJoinTokenRepo) GetByUserID(ctx context.Context, userID string) ([]*models.JoinTokenModel, error) {
	var result []*models.JoinTokenModel
	cursor, err := r.col.Find(ctx, bson.M{"user": userID})
	if err != nil {
		return nil, err
	}

	defer cursor.Close(ctx)

	for cursor.Next(ctx) {
		var token models.JoinTokenModel
		err := cursor.Decode(&token)
		if err != nil {
			return nil, err
		}

		result = append(result, &token)
	}

	if err := cursor.Err(); err != nil {
		return nil, err
	}

	return result, nil
}

func (r *mongoJoinTokenRepo) Create(ctx context.Context, token *models.JoinTokenModel) error {
	_, err := r.col.InsertOne(ctx, token)
	if err != nil {
		return err
	}

	return nil
}

func (r *mongoJoinTokenRepo) GetByToken(ctx context.Context, token string) (*models.JoinTokenModel, error) {
	tokenModel := &models.JoinTokenModel{}
	err := r.col.FindOne(ctx, bson.M{"token": token}).Decode(tokenModel)
	if err != nil {
		if errors.Is(err, mongo.ErrNoDocuments) {
			return nil, nil
		}

		return nil, err
	}

	return tokenModel, nil
}

func (r *mongoJoinTokenRepo) DeleteByToken(ctx context.Context, token string) error {
	return r.col.FindOneAndDelete(ctx, bson.M{"_id": token}).Err()
}
