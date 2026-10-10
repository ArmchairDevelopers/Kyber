package repository

import (
	"context"
	"errors"
	"strconv"
	"time"

	"github.com/ArmchairDevelopers/Kyber/API/pkg/ea"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/models"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/util"
	"go.mongodb.org/mongo-driver/v2/mongo"

	"go.mongodb.org/mongo-driver/v2/bson"
)

type UserRepository interface {
	GetByID(ctx context.Context, id string) (*models.UserModel, error)
	GetByName(ctx context.Context, name string) (*models.UserModel, error)
	GetByDoc(ctx context.Context, doc bson.M) (*models.UserModel, error)
	SearchByIDs(ctx context.Context, ids []string) ([]*models.UserModel, error)
	Create(ctx context.Context, persona ea.JwtUserPersonaInformationClaims, claims ea.EAJwtNexusClaims, ip string) (*models.UserModel, error)
	GetByToken(ctx context.Context, token string) (*models.UserModel, error)
	GetByDiscordID(ctx context.Context, discordID string) (*models.UserModel, error)
	UpdateAndReplace(ctx context.Context, user *models.UserModel) error
	Update(ctx context.Context, id string, doc bson.M) error
	ModeratedServers(ctx context.Context, userID string) ([]string, error)
	GetPatronNames(ctx context.Context) (*[]string, error)
	SearchByName(ctx context.Context, name string) (*models.UserModel, error)
	SearchMulti(ctx context.Context, name string) ([]*models.UserModel, error)
}

type mongoUserRepo struct {
	col mongo.Collection
}

func NewUserRepo(col *mongo.Collection) UserRepository {
	return &mongoUserRepo{col: *col}
}

func (r *mongoUserRepo) SearchMulti(ctx context.Context, name string) ([]*models.UserModel, error) {
	var results []*models.UserModel
	cursor, err := r.col.Find(ctx, bson.M{"name": bson.M{"$regex": "^" + name + "$", "$options": "i"}})
	if err != nil {
		return nil, err
	}
	defer cursor.Close(ctx)

	if err := cursor.All(ctx, &results); err != nil {
		return nil, err
	}

	return results, nil
}

func (r *mongoUserRepo) SearchByName(ctx context.Context, name string) (*models.UserModel, error) {
	return r.GetByDoc(ctx, bson.M{"name": bson.M{"$regex": "^" + name + "$", "$options": "i"}})
}

func (r *mongoUserRepo) GetByName(ctx context.Context, name string) (*models.UserModel, error) {
	return r.GetByDoc(ctx, bson.M{"name": name})
}

func (r *mongoUserRepo) Update(ctx context.Context, id string, m bson.M) error {
	_, err := r.col.UpdateOne(ctx, bson.M{"_id": id}, m)

	return err
}

func (r *mongoUserRepo) GetByDoc(ctx context.Context, doc bson.M) (*models.UserModel, error) {
	var result models.UserModel
	err := r.col.FindOne(ctx, doc).Decode(&result)
	if err != nil {
		if errors.Is(err, mongo.ErrNoDocuments) {
			return nil, nil
		}

		return nil, err
	}

	return &result, nil
}

func (r *mongoUserRepo) SearchByIDs(ctx context.Context, ids []string) ([]*models.UserModel, error) {
	var results []*models.UserModel
	cursor, err := r.col.Find(ctx, bson.M{"_id": bson.M{"$in": ids}})
	if err != nil {
		return nil, err
	}
	defer cursor.Close(ctx)

	if err := cursor.All(ctx, &results); err != nil {
		return nil, err
	}

	return results, nil
}

func (r *mongoUserRepo) UpdateAndReplace(ctx context.Context, user *models.UserModel) error {
	return r.col.FindOneAndReplace(ctx, bson.M{"_id": user.ID}, user).Err()
}

func (r *mongoUserRepo) GetByToken(ctx context.Context, token string) (*models.UserModel, error) {
	return r.GetByDoc(ctx, bson.M{"token": token})
}

func (r *mongoUserRepo) GetByDiscordID(ctx context.Context, discordID string) (*models.UserModel, error) {
	return r.GetByDoc(ctx, bson.M{"$or": bson.A{
		bson.M{"discord_data.id": discordID},
		bson.M{"patreon_data.discord_id": discordID},
	}})
}

func (r *mongoUserRepo) GetByID(ctx context.Context, id string) (*models.UserModel, error) {
	return r.GetByDoc(ctx, bson.M{"_id": id})
}

func (r *mongoUserRepo) GetPatronNames(ctx context.Context) (*[]string, error) {
	var results []models.UserModel
	cursor, err := r.col.Find(ctx, bson.M{"patreon_data": bson.M{"$ne": nil, "$exists": true}})
	if err != nil {
		return nil, err
	}

	defer cursor.Close(ctx)

	if err := cursor.All(ctx, &results); err != nil {
		return nil, err
	}

	names := make([]string, len(results))
	for i, user := range results {
		names[i] = user.Name
	}

	return &names, nil
}

func (r *mongoUserRepo) ModeratedServers(ctx context.Context, userID string) ([]string, error) {
	pipeline := mongo.Pipeline{
		bson.D{{"$match", bson.D{{"$or", bson.A{
			bson.D{{"moderator_user_ids", userID}},
			bson.D{{"_id", userID}},
		}}}}},
		bson.D{{"$lookup", bson.D{
			{"from", "servers"},
			{"localField", "_id"},
			{"foreignField", "host_id"},
			{"as", "hostedServers"},
		}}},
		bson.D{{"$unwind", "$hostedServers"}},
		bson.D{{"$facet", bson.D{
			{"moderated", bson.A{
				bson.D{{"$match", bson.D{{"moderator_user_ids", userID}}}},
				bson.D{{"$lookup", bson.D{
					{"from", "servers"},
					{"localField", "_id"},
					{"foreignField", "host_id"},
					{"as", "servers"},
				}}},
				bson.D{{"$unwind", "$servers"}},
				bson.D{{"$project", bson.D{{"serverId", "$servers._id"}}}},
			}},
			{"hosted", bson.A{
				bson.D{{"$match", bson.D{{"_id", userID}}}},
				bson.D{{"$project", bson.D{{"serverId", "$hostedServers._id"}}}},
			}},
		}}},
		bson.D{{"$project", bson.D{
			{"allServerIds", bson.D{{"$setUnion", bson.A{"$moderated.serverId", "$hosted.serverId"}}}},
		}}},
	}

	cursor, err := r.col.Aggregate(ctx, pipeline)
	if err != nil {
		return nil, err
	}
	defer cursor.Close(ctx)

	var docs []struct {
		AllServerIds []string `bson:"allServerIds"`
	}
	if err := cursor.All(ctx, &docs); err != nil {
		return nil, err
	}
	if len(docs) == 0 {
		return nil, nil
	}
	return docs[0].AllServerIds, nil
}

func (r *mongoUserRepo) Create(ctx context.Context, persona ea.JwtUserPersonaInformationClaims, claims ea.EAJwtNexusClaims, ip string) (*models.UserModel, error) {
	user := models.UserModel{
		ID:           claims.Pid,
		Name:         persona.Dis,
		Entitlements: make([]models.UserEntitlement, 0),
		Created:      time.Now(),
		LastSeen:     time.Now(),
		Token:        util.GenerateToken(),
		IPs: []models.UserIP{
			{
				IP:        ip,
				LastSeen:  time.Now(),
				FirstSeen: time.Now(),
			},
		},
		EAData: models.EAUserData{
			PersonaID:      strconv.FormatUint(claims.Psid, 10),
			Country:        claims.Uif.Cty,
			Language:       claims.Uif.Lan,
			DisplayName:    persona.Dis,
			NameOnRegister: &persona.Dis,
			Nickname:       persona.Nic,
			UserID:         claims.Uid,
			IsBanned:       false,
			DeviceIDs: []models.EADeviceID{
				{
					ID:        claims.Dvid,
					LastSeen:  time.Now(),
					FirstSeen: time.Now(),
				},
			},
		},
		BannedUserIDs:    make([]string, 0),
		ModeratorUserIDs: make([]string, 0),
		PatreonData:      nil,
		MetricData: models.UserMetricData{
			LoginCount:    0,
			ServersHosted: 0,
			ServersJoined: 0,
		},
		VPNBlocked: false,
	}

	_, err := r.col.InsertOne(ctx, user)
	if err != nil {
		return nil, err
	}

	return &user, nil
}
