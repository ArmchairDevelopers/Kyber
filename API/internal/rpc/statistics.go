package rpc

import (
	"bytes"
	"context"
	"encoding/json"
	"log"
	"os"

	"github.com/ArmchairDevelopers/Kyber/API/api/v1/pbapi"
	"github.com/ArmchairDevelopers/Kyber/API/api/v1/pbcommon"
	"github.com/ArmchairDevelopers/Kyber/API/api/v1/pbea"
	"github.com/ArmchairDevelopers/Kyber/API/internal/cache"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/db"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/logger"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/models"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/util"
	"github.com/elastic/go-elasticsearch/v9"
	"github.com/elastic/go-elasticsearch/v9/typedapi/types"
	"go.uber.org/zap"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/status"
)

type StatisticsServer struct {
	store               *db.Store
	statsCache          *cache.StatsCache
	statsClient         *pbea.StatisticsClient
	usersClient         *pbea.UsersClient
	elasticsearchClient *elasticsearch.TypedClient
	pbapi.UnimplementedStatisticsServer
}

func NewStatisticsServer(ctx context.Context, store *db.Store, caches *cache.Caches) *StatisticsServer {
	var statsClient *pbea.StatisticsClient
	var usersClient *pbea.UsersClient

	eaBridgeAddr := os.Getenv("KYBER_EA_BRIDGE")
	if eaBridgeAddr != "" {
		conn, err := grpc.DialContext(ctx, eaBridgeAddr,
			grpc.WithTransportCredentials(insecure.NewCredentials()),
			grpc.WithBlock(),
		)
		if err != nil {
			log.Fatalf("failed to dial gRPC server: %v", zap.Error(err))
		}

		sc := pbea.NewStatisticsClient(conn)
		uc := pbea.NewUsersClient(conn)

		statsClient = &sc
		usersClient = &uc
	}

	var es *elasticsearch.TypedClient
	elasticSearchURL := os.Getenv("ELASTICSEARCH_URL")
	if elasticSearchURL != "" {
		cfg := elasticsearch.Config{
			Addresses: []string{elasticSearchURL},
		}

		var err error
		es, err = elasticsearch.NewTypedClient(cfg)
		if err != nil {
			panic(zap.Error(err))
		}
	}

	return &StatisticsServer{
		store:               store,
		statsClient:         statsClient,
		usersClient:         usersClient,
		statsCache:          caches.Stats,
		elasticsearchClient: es,
	}
}

func (s *StatisticsServer) SearchUser(ctx context.Context, req *pbapi.StatsSearchRequest) (*pbapi.StatsSearchResponse, error) {
	if req.GetQuery() == "" || len(req.GetQuery()) < 1 {
		return &pbapi.StatsSearchResponse{
			Users: make([]*pbapi.EAUser, 0),
		}, nil
	}

	if s.elasticsearchClient != nil {
		body := map[string]interface{}{
			"query": map[string]interface{}{
				"match_phrase_prefix": map[string]interface{}{
					"name": map[string]interface{}{
						"query":          req.GetQuery(),
						"slop":           1,
						"max_expansions": 50,
					},
				},
			},
		}

		var buf bytes.Buffer
		if err := json.NewEncoder(&buf).Encode(body); err != nil {
			log.Fatalf("Error encoding query: %s", err)
		}

		query := &types.Query{
			MatchPhrasePrefix: map[string]types.MatchPhrasePrefixQuery{
				"name": {
					Query:         req.GetQuery(),
					Slop:          util.ToPtr(1),
					MaxExpansions: util.ToPtr(50),
				},
			},
		}

		result, err := s.elasticsearchClient.
			Search().
			Header("Content-Type", "application/json").
			Header("Accept", "application/json").
			Index("users-index").
			Query(query).
			Do(ctx)
		if err != nil {
			logger.L().Error("Failed to search user in Elasticsearch", zap.Error(err))
			return nil, status.Error(codes.Internal, "Failed to search user")
		}

		mapped := make([]*pbapi.EAUser, len(result.Hits.Hits))
		for i, hit := range result.Hits.Hits {
			var source struct {
				ID       string `json:"id"`
				Username string `json:"name"`
			}
			if err := json.Unmarshal(hit.Source_, &source); err != nil {
				logger.L().Error("Failed to unmarshal Elasticsearch hit", zap.Error(err))
				return nil, status.Error(codes.Internal, "Failed to search user")
			}

			mapped[i] = &pbapi.EAUser{
				Id:          source.ID,
				Username:    source.Username,
				IsKyberUser: true,
			}
		}

		return &pbapi.StatsSearchResponse{
			Users: mapped,
		}, nil
	}

	users, err := s.store.Users.SearchMulti(ctx, req.GetQuery())
	if err != nil {
		logger.L().Error("Failed to get users", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get users")
	}

	mappedUsers := make([]*pbapi.EAUser, len(users))
	for i, user := range users {
		mappedUsers[i] = &pbapi.EAUser{
			Id:          user.ID,
			Username:    user.Name,
			IsKyberUser: true,
		}
	}

	return &pbapi.StatsSearchResponse{
		Users: mappedUsers,
	}, nil
}

func (s *StatisticsServer) getUserStats(ctx context.Context, id string, source string) (*models.UserStatsModel, error) {
	user, err := s.store.Users.GetByID(ctx, id)
	if err != nil {
		logger.L().Error("Failed to get user", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get user")
	}

	if user == nil {
		return nil, status.Error(codes.NotFound, "User not found")
	}

	stats, err := s.store.Stats.Get(ctx, user.ID, source)
	if err != nil {
		logger.L().Error("Failed to get stats", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get stats")
	}

	if stats == nil {
		return nil, nil
	}

	return stats, nil
}

func (s *StatisticsServer) GetStats(ctx context.Context, req *pbapi.StatsRequest) (*pbapi.StatsResponse, error) {
	switch req.GetSource() {
	case pbapi.StatsSource_EA_PC:
		cachedStats, err := s.statsCache.Get(ctx, req.GetPersonaId(), models.StatsSourceEA)
		if err != nil {
			logger.L().Error("Failed to get cached stats", zap.Error(err))
			return nil, status.Error(codes.Internal, "Failed to get cached stats")
		}

		if cachedStats != nil {
			return &pbapi.StatsResponse{
				Stats: models.ConvertStats(cachedStats.Stats),
			}, nil
		}

		if s.statsClient == nil {
			logger.L().Error("EA Stats client is not initialized")
			return nil, status.Error(codes.Unavailable, "EA Stats client is not available")
		}

		eaRes, err := (*s.statsClient).GetStats(ctx, &pbea.EAStatsRequest{
			PersonaId: req.GetPersonaId(),
			Platform:  pbea.EAPlatform_PC,
		})
		if err != nil {
			logger.L().Error("Failed to get EA stats", zap.Error(err))
			return nil, status.Error(codes.Internal, "Failed to get EA stats")
		}

		if eaRes == nil {
			return nil, status.Error(codes.Internal, "Failed to get EA stats")
		}

		stats := &models.UserStatsModel{
			UserID: req.GetPersonaId(),
			Stats:  eaRes.GetStats(),
			Source: models.StatsSourceEA,
		}

		err = s.statsCache.Set(ctx, stats)
		if err != nil {
			logger.L().Error("Failed to set cached stats", zap.Error(err))
			return nil, status.Error(codes.Internal, "Internal error")
		}

		return &pbapi.StatsResponse{
			Stats: models.ConvertStats(eaRes.GetStats()),
		}, nil

	case pbapi.StatsSource_KYBER:
		stats, err := s.getUserStats(ctx, req.GetUser(), string(models.StatsSourceKyber))
		if err != nil {
			logger.L().Error("Failed to get Kyber stats", zap.Error(err))
			return nil, err
		}

		if stats == nil {
			return &pbapi.StatsResponse{
				Stats: make(map[string]float32),
			}, nil
		}

		return &pbapi.StatsResponse{
			Stats: models.ConvertStats(stats.Stats),
		}, nil
	case pbapi.StatsSource_PERSONAL:
		owner := ctx.Value("user").(*models.UserModel)
		stats, err := s.getUserStats(ctx, owner.ID, string(models.StatsSourcePersonal))
		if err != nil {
			logger.L().Error("Failed to get personal stats", zap.Error(err))
			return nil, err
		}

		if stats == nil {
			return nil, status.Error(codes.NotFound, "Stats not found")
		}

		return &pbapi.StatsResponse{
			Stats: models.ConvertStats(stats.Stats),
		}, nil
	}

	return nil, status.Error(codes.InvalidArgument, "Invalid stats source")
}

func (s *StatisticsServer) UpdateStats(ctx context.Context, req *pbapi.UpdateStatsRequest) (*pbcommon.Empty, error) {
	owner := ctx.Value("user").(*models.UserModel)

	if req.GetSource() != pbapi.StatsSource_KYBER {
		return nil, status.Error(codes.InvalidArgument, "Only Kyber stats can be updated")
	}

	user, err := s.store.Users.GetByID(ctx, req.GetUser())
	if err != nil {
		logger.L().Error("Failed to get user", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get user")
	}

	if user == nil {
		return nil, status.Error(codes.NotFound, "User not found")
	}

	if req.GetSource() == pbapi.StatsSource_KYBER {
		if !owner.Entitled(models.EntitlementOfficialStats) {
			return nil, status.Error(codes.PermissionDenied, "You do not have permission to update Kyber stats")
		}

		currentStats, _ := s.store.Stats.Get(ctx, user.ID, string(models.StatsSourceKyber))

		if currentStats != nil {
			if len(req.GetStats()) < len(currentStats.Stats) {
				logger.L().Info("Provided stats are: ", zap.Int("provided", len(req.GetStats())), zap.Int("current", len(currentStats.Stats)))

				for key, _ := range currentStats.Stats {
					if _, ok := req.Stats[key]; !ok {
						logger.L().Info("Missing stat key: " + key)
					}
				}

				return nil, status.Error(codes.InvalidArgument, "Insufficient stats provided")
			}
		}
	}

	err = s.store.Stats.Upsert(ctx, owner.ID, user.ID, models.StatsSourceFromProto(req.Source), models.FromProtoStats(req.GetStats()))
	if err != nil {
		logger.L().Error("Failed to update stats", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to update stats")
	}

	return &pbcommon.Empty{}, nil
}
