package repository

import (
	"context"
	"errors"
	"time"

	"github.com/ArmchairDevelopers/Kyber/API/pkg/models"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
)

type ServerRepository interface {
	GetByID(ctx context.Context, id string) (*models.ServerModel, error)
	Create(ctx context.Context, server *models.ServerModel) (*models.ServerModel, error)
	Update(ctx context.Context, server *models.ServerModel) (*models.ServerModel, error)
	UpdateByID(ctx context.Context, id string, doc bson.M) error
	GetIDs(ctx context.Context) ([]string, error)
	GetByDoc(ctx context.Context, doc bson.M) ([]*models.ServerModel, error)
	GetByIDs(ctx context.Context, ids []string) ([]*models.ServerModel, error)
	GetPublic(ctx context.Context) ([]*models.ServerModel, error)
	GetAll(ctx context.Context) ([]*models.ServerModel, error)
	GetWithCutoff(ctx context.Context, cutoff time.Time) ([]*models.ServerModel, error)
	GetByHostID(ctx context.Context, hostID string) ([]*models.ServerModel, error)
	DeleteMany(ctx context.Context, ids []string) error
}

type mongoServerRepo struct {
	col mongo.Collection
}

func NewServerRepository(col *mongo.Collection) ServerRepository {
	return &mongoServerRepo{col: *col}
}

func (r *mongoServerRepo) GetByDoc(ctx context.Context, doc bson.M) ([]*models.ServerModel, error) {
	cursor, err := r.col.Find(ctx, doc)
	if err != nil {
		return nil, err
	}
	defer cursor.Close(ctx)

	var servers []*models.ServerModel
	for cursor.Next(ctx) {
		var server models.ServerModel
		err := cursor.Decode(&server)
		if err != nil {
			return nil, err
		}
		servers = append(servers, &server)
	}

	if err := cursor.Err(); err != nil {
		return nil, err
	}

	return servers, nil
}

func (r *mongoServerRepo) GetByHostID(ctx context.Context, hostID string) ([]*models.ServerModel, error) {
	return r.GetByDoc(ctx, bson.M{"host_id": hostID})
}

func (r *mongoServerRepo) GetAll(ctx context.Context) ([]*models.ServerModel, error) {
	return r.GetByDoc(ctx, bson.M{})
}

func (r *mongoServerRepo) DeleteMany(ctx context.Context, ids []string) error {
	if len(ids) == 0 {
		return nil
	}

	_, err := r.col.DeleteMany(ctx, bson.M{"_id": bson.M{"$in": ids}})
	return err
}

func (r *mongoServerRepo) GetWithCutoff(ctx context.Context, cutoff time.Time) ([]*models.ServerModel, error) {
	return r.GetByDoc(ctx, bson.M{"last_updated": bson.M{"$lt": cutoff}})
}

func (r *mongoServerRepo) GetPublic(ctx context.Context) ([]*models.ServerModel, error) {
	return r.GetByDoc(ctx, bson.M{"metadata.hide_from_browser": bson.M{"$ne": true}})
}

func (r *mongoServerRepo) UpdateByID(ctx context.Context, id string, doc bson.M) error {
	result, err := r.col.UpdateOne(ctx, bson.M{"_id": id}, doc)
	if err != nil {
		return err
	}

	if result.MatchedCount == 0 {
		return mongo.ErrNoDocuments
	}

	return nil
}

func (r *mongoServerRepo) GetByIDs(ctx context.Context, ids []string) ([]*models.ServerModel, error) {
	if len(ids) == 0 {
		return nil, nil
	}

	return r.GetByDoc(ctx, bson.M{"_id": bson.M{"$in": ids}})
}

func (r *mongoServerRepo) GetIDs(ctx context.Context) ([]string, error) {
	cursor, err := r.col.Find(ctx, bson.M{})
	if err != nil {
		return nil, err
	}
	defer cursor.Close(ctx)

	var ids []string
	for cursor.Next(ctx) {
		var server models.ServerModel
		err := cursor.Decode(&server)
		if err != nil {
			return nil, err
		}
		ids = append(ids, server.ID)
	}

	if err := cursor.Err(); err != nil {
		return nil, err
	}

	return ids, nil
}

func (r *mongoServerRepo) Update(ctx context.Context, server *models.ServerModel) (*models.ServerModel, error) {
	_, err := r.col.UpdateOne(ctx, bson.M{"_id": server.ID}, bson.M{"$set": server})
	if err != nil {
		return nil, err
	}

	return server, nil

}

func (r *mongoServerRepo) Create(ctx context.Context, server *models.ServerModel) (*models.ServerModel, error) {
	_, err := r.col.InsertOne(ctx, server)
	if err != nil {
		return nil, err
	}

	return server, nil
}

func (r *mongoServerRepo) GetByID(ctx context.Context, id string) (*models.ServerModel, error) {
	server := &models.ServerModel{}
	err := r.col.FindOne(ctx, bson.M{"_id": id}).Decode(server)
	if err != nil {
		if errors.Is(err, mongo.ErrNoDocuments) {
			return nil, nil
		}

		return nil, err
	}

	return server, nil
}
