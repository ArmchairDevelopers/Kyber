package repository

import (
	"context"
	"errors"

	"github.com/ArmchairDevelopers/Kyber/API/pkg/models"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

type PartyRepository interface {
	Create(ctx context.Context, party *models.PartyModel) error
	GetByID(ctx context.Context, partyID uint64) (*models.PartyModel, error)
	Update(ctx context.Context, partyID uint64, update interface{}) error
	Delete(ctx context.Context, partyID uint64) error
	GetNextID(ctx context.Context) (uint64, error)
}

type mongoPartyRepo struct {
	col mongo.Collection
}

func NewPartyRepo(col *mongo.Collection) PartyRepository {
	return &mongoPartyRepo{col: *col}
}

func (r *mongoPartyRepo) Create(ctx context.Context, party *models.PartyModel) error {
	_, err := r.col.InsertOne(ctx, party)
	return err
}

func (r *mongoPartyRepo) GetByID(ctx context.Context, partyID uint64) (*models.PartyModel, error) {
	var party models.PartyModel
	err := r.col.FindOne(ctx, bson.M{"_id": partyID}).Decode(&party)
	if err != nil {
		if errors.Is(err, mongo.ErrNoDocuments) {
			return nil, nil
		}
		return nil, err
	}
	return &party, nil
}

func (r *mongoPartyRepo) Update(ctx context.Context, partyID uint64, update interface{}) error {
	_, err := r.col.UpdateOne(ctx, bson.M{"_id": partyID}, update)
	return err
}

func (r *mongoPartyRepo) Delete(ctx context.Context, partyID uint64) error {
	_, err := r.col.DeleteOne(ctx, bson.M{"_id": partyID})
	return err
}

func (r *mongoPartyRepo) GetNextID(ctx context.Context) (uint64, error) {
	opts := options.FindOne().SetSort(bson.M{"_id": -1})
	var result models.PartyModel
	err := r.col.FindOne(ctx, bson.M{}, opts).Decode(&result)
	if err != nil {
		if errors.Is(err, mongo.ErrNoDocuments) {
			return 1000, nil
		}

		return 0, err
	}
	return result.ID + 1, nil
}
