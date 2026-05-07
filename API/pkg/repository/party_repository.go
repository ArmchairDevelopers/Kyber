package repository

import (
	"context"
	"errors"
	"math/rand"

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
	MarkMemberJoined(ctx context.Context, partyID uint64, userID, serverID string) (*models.PartyJoinGameMemberStatus, error)
	UpdateMemberModStatus(ctx context.Context, partyID uint64, userID string, hasMods bool, modDownloadPercentage *uint32) (*models.PartyJoinGameMemberStatus, error)
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

func (r *mongoPartyRepo) MarkMemberJoined(ctx context.Context, partyID uint64, userID, serverID string) (*models.PartyJoinGameMemberStatus, error) {
	filter := bson.M{
		"_id":                       partyID,
		"join_game_state.server_id": serverID,
	}

	pipeline := bson.A{
		bson.M{"$set": bson.M{
			"join_game_state.member_statuses": bson.M{"$cond": bson.M{
				"if": bson.M{"$in": bson.A{
					userID,
					bson.M{"$ifNull": bson.A{"$join_game_state.member_statuses.user_id", bson.A{}}},
				}},
				"then": bson.M{"$map": bson.M{
					"input": "$join_game_state.member_statuses",
					"as":    "s",
					"in": bson.M{"$cond": bson.M{
						"if": bson.M{"$eq": bson.A{"$$s.user_id", userID}},
						"then": bson.M{"$mergeObjects": bson.A{
							"$$s",
							bson.M{"has_mods": true, "joined": true},
						}},
						"else": "$$s",
					}},
				}},
				"else": bson.M{"$concatArrays": bson.A{
					bson.M{"$ifNull": bson.A{"$join_game_state.member_statuses", bson.A{}}},
					bson.A{bson.M{
						"user_id":  userID,
						"has_mods": true,
						"joined":   true,
					}},
				}},
			}},
		}},
	}

	return r.findUserStatus(ctx, filter, pipeline, userID)
}

func (r *mongoPartyRepo) UpdateMemberModStatus(ctx context.Context, partyID uint64, userID string, hasMods bool, modDownloadPercentage *uint32) (*models.PartyJoinGameMemberStatus, error) {
	filter := bson.M{
		"_id":             partyID,
		"join_game_state": bson.M{"$exists": true},
	}

	var modValue interface{}
	if modDownloadPercentage != nil {
		modValue = *modDownloadPercentage
	}

	pipeline := bson.A{
		bson.M{"$set": bson.M{
			"join_game_state.member_statuses": bson.M{"$cond": bson.M{
				"if": bson.M{"$in": bson.A{
					userID,
					bson.M{"$ifNull": bson.A{"$join_game_state.member_statuses.user_id", bson.A{}}},
				}},
				"then": bson.M{"$map": bson.M{
					"input": "$join_game_state.member_statuses",
					"as":    "s",
					"in": bson.M{"$cond": bson.M{
						"if": bson.M{"$eq": bson.A{"$$s.user_id", userID}},
						"then": bson.M{"$mergeObjects": bson.A{
							"$$s",
							bson.M{
								"has_mods":                hasMods,
								"mod_download_percentage": modValue,
							},
						}},
						"else": "$$s",
					}},
				}},
				"else": bson.M{"$concatArrays": bson.A{
					bson.M{"$ifNull": bson.A{"$join_game_state.member_statuses", bson.A{}}},
					bson.A{bson.M{
						"user_id":                 userID,
						"has_mods":                hasMods,
						"mod_download_percentage": modValue,
						"joined":                  false,
					}},
				}},
			}},
		}},
	}

	return r.findUserStatus(ctx, filter, pipeline, userID)
}

func (r *mongoPartyRepo) findUserStatus(ctx context.Context, filter bson.M, pipeline bson.A, userID string) (*models.PartyJoinGameMemberStatus, error) {
	var party models.PartyModel
	err := r.col.FindOneAndUpdate(
		ctx, filter, pipeline,
		options.FindOneAndUpdate().SetReturnDocument(options.After),
	).Decode(&party)
	if err != nil {
		if errors.Is(err, mongo.ErrNoDocuments) {
			return nil, nil
		}

		return nil, err
	}

	if party.JoinGameState == nil {
		return nil, nil
	}

	for i := range party.JoinGameState.MemberStatuses {
		if party.JoinGameState.MemberStatuses[i].UserID == userID {
			return &party.JoinGameState.MemberStatuses[i], nil
		}
	}

	return nil, nil
}
