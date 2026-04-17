package repository

import (
	"context"

	"github.com/ArmchairDevelopers/Kyber/API/pkg/models"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
)

type HostedModRepository interface {
	Search(ctx context.Context, name string, version string) (*models.HostedMod, error)
	Create(ctx context.Context, mod *models.HostedMod) error
}

type mongoHostedModRepo struct {
	col mongo.Collection
}

func NewHostedModRepo(col *mongo.Collection) HostedModRepository {
	return &mongoHostedModRepo{col: *col}
}

func (r *mongoHostedModRepo) Create(ctx context.Context, mod *models.HostedMod) error {
	_, err := r.col.InsertOne(ctx, mod)
	if err != nil {
		return err
	}
	return nil
}

// TODO: implement search by hash

func (r *mongoHostedModRepo) Search(ctx context.Context, name string, version string) (*models.HostedMod, error) {
	matchFilter := bson.D{
		{"mods.name", name},
		{"mods.version", version},
	}

	pipeline := mongo.Pipeline{
		{{Key: "$match", Value: matchFilter}},
		{{Key: "$project", Value: bson.D{
			{"_id", 1},
			{"name", 1},
			{"version", 1},
			{"file_name", 1},
			{"mods", 1},
			{"array_length", bson.D{{"$size", "$mods"}}},
			{"created", 1},
			{"updated", 1},
		}}},
		{{Key: "$sort", Value: bson.D{{"array_length", 1}}}},
		{{Key: "$limit", Value: 1}},
	}

	cursor, err := r.col.Aggregate(ctx, pipeline)
	if err != nil {
		return nil, err
	}
	defer cursor.Close(ctx)

	if cursor.Next(ctx) {
		var mod models.HostedMod
		if err := cursor.Decode(&mod); err != nil {
			return nil, err
		}

		return &mod, nil
	}

	return nil, nil
}
