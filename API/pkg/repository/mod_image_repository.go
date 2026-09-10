package repository

import (
	"context"
	"errors"

	"github.com/ArmchairDevelopers/Kyber/API/pkg/models"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
)

type ModImageRepository interface {
	Search(ctx context.Context, hash string) (*models.ModImageModel, error)
	SearchWithFilter(ctx context.Context, filter bson.M) (*models.ModImageModel, error)
	SearchMulti(ctx context.Context, hashes []string) (*models.ModImageModel, error)
	SearchMapImage(ctx context.Context, level string, mode string, mods []models.ModImageModModel) (*models.ModImageModel, error)
	Update(ctx context.Context, id string, doc bson.M) error
	Create(ctx context.Context, imageHash *models.ModImageModel) error
	GetByID(ctx context.Context, id string) (*models.ModImageModel, error)
	GetBulkByIDs(ctx context.Context, ids []string) ([]*models.ModImageModel, error)
	GetActiveByID(ctx context.Context, id string) (*models.ModImageModel, error)
}

type mongoModImageRepo struct {
	col mongo.Collection
}

func NewModImageRepo(col *mongo.Collection) ModImageRepository {
	return &mongoModImageRepo{col: *col}
}

func (r *mongoModImageRepo) GetBulkByIDs(ctx context.Context, ids []string) ([]*models.ModImageModel, error) {
	if len(ids) == 0 {
		return nil, nil
	}

	filter := bson.M{"_id": bson.M{"$in": ids}}
	cursor, err := r.col.Find(ctx, filter)
	if err != nil {
		return nil, err
	}

	defer cursor.Close(ctx)

	var images []*models.ModImageModel
	for cursor.Next(ctx) {
		var image models.ModImageModel
		if err := cursor.Decode(&image); err != nil {
			return nil, err
		}

		images = append(images, &image)
	}

	if err := cursor.Err(); err != nil {
		return nil, err
	}

	return images, nil
}

func (r *mongoModImageRepo) SearchMapImage(ctx context.Context, level string, mode string, mods []models.ModImageModModel) (*models.ModImageModel, error) {
	filter := bson.M{
		"levels": bson.M{
			"$in": []string{level},
		},
		"modes": bson.M{
			"$in": []string{mode},
		},
		"mods": bson.M{
			"$in": mods,
		},
	}

	var imageHash models.ModImageModel
	err := r.col.FindOne(ctx, filter).Decode(&imageHash)
	if err != nil {
		if errors.Is(err, mongo.ErrNoDocuments) {
			return nil, nil
		}

		return nil, err
	}

	return &imageHash, nil
}

func (r *mongoModImageRepo) GetActiveByID(ctx context.Context, id string) (*models.ModImageModel, error) {
	filter := bson.M{"_id": id, "status": models.ImageHashStatusApproved}
	var imageHash models.ModImageModel

	err := r.col.FindOne(ctx, filter).Decode(&imageHash)
	if err != nil {
		if errors.Is(err, mongo.ErrNoDocuments) {
			return nil, nil
		}

		return nil, err
	}

	return &imageHash, nil
}

func (r *mongoModImageRepo) GetByID(ctx context.Context, id string) (*models.ModImageModel, error) {
	filter := bson.M{"_id": id}
	var imageHash models.ModImageModel

	err := r.col.FindOne(ctx, filter).Decode(&imageHash)
	if err != nil {
		if errors.Is(err, mongo.ErrNoDocuments) {
			return nil, nil
		}

		return nil, err
	}

	return &imageHash, nil
}

func (r *mongoModImageRepo) SearchMulti(ctx context.Context, hashes []string) (*models.ModImageModel, error) {
	filter := bson.M{"hash": bson.M{"$in": hashes}}
	var imageHash models.ModImageModel
	err := r.col.FindOne(ctx, filter).Decode(&imageHash)
	if err != nil {
		if errors.Is(err, mongo.ErrNoDocuments) {
			return nil, nil
		}

		return nil, err
	}

	return &imageHash, nil
}

func (r *mongoModImageRepo) SearchWithFilter(ctx context.Context, filter bson.M) (*models.ModImageModel, error) {
	var imageHash models.ModImageModel
	err := r.col.FindOne(ctx, filter).Decode(&imageHash)
	if err != nil {
		if errors.Is(err, mongo.ErrNoDocuments) {
			return nil, nil
		}

		return nil, err
	}

	return &imageHash, nil
}

func (r *mongoModImageRepo) Create(ctx context.Context, imageHash *models.ModImageModel) error {
	_, err := r.col.InsertOne(ctx, imageHash)
	if err != nil {
		return err
	}
	return nil
}

func (r *mongoModImageRepo) Search(ctx context.Context, hash string) (*models.ModImageModel, error) {
	filter := bson.M{"_id": hash}
	var imageHash models.ModImageModel
	err := r.col.FindOne(ctx, filter).Decode(&imageHash)
	if err != nil {
		if errors.Is(err, mongo.ErrNoDocuments) {
			return nil, nil
		}

		return nil, err
	}

	return &imageHash, nil
}

func (r *mongoModImageRepo) Update(ctx context.Context, id string, doc bson.M) error {
	filter := bson.M{"_id": id}

	result, err := r.col.UpdateOne(ctx, filter, doc)
	if err != nil {
		return err
	}

	if result.MatchedCount == 0 {
		return mongo.ErrNoDocuments
	}

	return nil
}
