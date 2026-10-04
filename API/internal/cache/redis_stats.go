package cache

import (
	"context"
	"time"

	"github.com/ArmchairDevelopers/Kyber/API/pkg/models"
	"github.com/redis/go-redis/v9"
)

const userStatsKeyPrefix = "user_stats"

type StatsCache struct {
	s store
}

func NewStatsCache(rdb *redis.Client, ttl time.Duration) *StatsCache {
	return &StatsCache{s: newStore(rdb, userStatsKeyPrefix, ttl)}
}

func (c *StatsCache) Get(ctx context.Context, userID string, source models.StatsSource) (*models.UserStatsModel, error) {
	return getJSON[models.UserStatsModel](ctx, c.s, userID, string(source))
}

func (c *StatsCache) Set(ctx context.Context, m *models.UserStatsModel) error {
	return setJSON(ctx, c.s, m, m.UserID, string(m.Source))
}

func (c *StatsCache) Delete(ctx context.Context, userID string, source models.StatsSource) error {
	return c.s.del(ctx, userID, string(source))
}
