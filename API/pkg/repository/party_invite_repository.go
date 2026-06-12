package repository

import (
	"context"
	"errors"
	"time"

	"github.com/ArmchairDevelopers/Kyber/API/pkg/models"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
)

type PartyInviteRepository interface {
	Create(ctx context.Context, invite *models.PartyInviteModel) error
	GetInvites(ctx context.Context, partyID uint64) ([]*models.PartyInviteModel, error)
	GetActiveInvitesByPartyID(ctx context.Context, partyID uint64) ([]*models.PartyInviteModel, error)
	Delete(ctx context.Context, id string) error
	GetByInvitee(ctx context.Context, partyID uint64, inviteeID string) (*models.PartyInviteModel, error)
}

type mongoPartyInviteRepo struct {
	col mongo.Collection
}

func NewPartyInviteRepo(col *mongo.Collection) PartyInviteRepository {
	return &mongoPartyInviteRepo{col: *col}
}

func (r *mongoPartyInviteRepo) Create(ctx context.Context, invite *models.PartyInviteModel) error {
	_, err := r.col.InsertOne(ctx, invite)
	return err
}

func (r *mongoPartyInviteRepo) GetInvites(ctx context.Context, partyID uint64) ([]*models.PartyInviteModel, error) {
	var invites []*models.PartyInviteModel
	cursor, err := r.col.Find(ctx, bson.M{"party_id": partyID})
	if err != nil {
		return nil, err
	}
	defer cursor.Close(ctx)

	if err := cursor.All(ctx, &invites); err != nil {
		return nil, err
	}

	return invites, nil
}

func (r *mongoPartyInviteRepo) GetActiveInvitesByPartyID(ctx context.Context, partyID uint64) ([]*models.PartyInviteModel, error) {
	var invites []*models.PartyInviteModel
	cursor, err := r.col.Find(ctx, bson.M{"party_id": partyID, "expires_at": bson.M{"$gt": time.Now()}})
	if err != nil {
		return nil, err
	}
	defer cursor.Close(ctx)

	if err := cursor.All(ctx, &invites); err != nil {
		return nil, err
	}

	return invites, nil
}

func (r *mongoPartyInviteRepo) Delete(ctx context.Context, id string) error {
	_, err := r.col.DeleteOne(ctx, bson.M{"_id": id})
	return err
}

func (r *mongoPartyInviteRepo) GetByInvitee(ctx context.Context, partyID uint64, inviteeID string) (*models.PartyInviteModel, error) {
	var invite models.PartyInviteModel
	err := r.col.FindOne(ctx, bson.M{"invitee_id": inviteeID, "party_id": partyID}).Decode(&invite)
	if err != nil {
		if errors.Is(err, mongo.ErrNoDocuments) {
			return nil, nil
		}

		return nil, err
	}

	return &invite, nil
}
