package repository

import (
	"context"
	"errors"
	"math/rand"

	"github.com/ArmchairDevelopers/Kyber/API/pkg/models"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
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
	for i := 0; i < 10; i++ {
		id := uint64(rand.Int63n(1<<62-1000)) + 1000
		err := r.col.FindOne(ctx, bson.M{"_id": id}).Err()
		if errors.Is(err, mongo.ErrNoDocuments) {
			return id, nil
		}
		if err != nil {
			return 0, err
		}
	}

	return 0, errors.New("failed to find unused party id after 10 attempts")
}
