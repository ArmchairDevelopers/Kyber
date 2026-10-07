package cache

import (
	"context"
	"encoding/json"
	"errors"
	"strings"
	"time"

	"github.com/ArmchairDevelopers/Kyber/API/pkg/logger"
	"github.com/redis/go-redis/v9"
	"go.uber.org/zap"
)

const defaultTTL = 5 * time.Minute

func NewRedisClient(redisURL string) (*redis.Client, error) {
	opts, err := redis.ParseURL(redisURL)
	if err != nil {
		logger.L().Error("failed to parse Redis URL", zap.Error(err))
		return nil, err
	}

	rdb := redis.NewClient(opts)
	if err := rdb.Ping(context.Background()).Err(); err != nil {
		logger.L().Error("failed to connect to Redis", zap.Error(err))
		return nil, err
	}

	return rdb, nil
}

type Caches struct {
	Stats       *StatsCache
	Patrons     *PatronsCache
	DiscordAuth *DiscordAuthCache
	ServerID    *ServerIDCache
}

func New(rdb *redis.Client) *Caches {
	return &Caches{
		Stats:       NewStatsCache(rdb, 10*time.Minute),
		Patrons:     NewPatronsCache(rdb, time.Hour),
		DiscordAuth: NewDiscordAuthCache(rdb, 5*time.Minute),
		ServerID:    NewServerIDCache(rdb, 2*time.Minute),
	}
}

type store struct {
	rdb    *redis.Client
	prefix string
	ttl    time.Duration
}

func newStore(rdb *redis.Client, prefix string, ttl time.Duration) store {
	if ttl <= 0 {
		ttl = defaultTTL
	}
	return store{rdb: rdb, prefix: prefix, ttl: ttl}
}

func (s store) key(parts ...string) string {
	return strings.Join(append([]string{s.prefix}, parts...), ":")
}

func (s store) get(ctx context.Context, parts ...string) (*string, error) {
	value, err := s.rdb.Get(ctx, s.key(parts...)).Result()

	if errors.Is(err, redis.Nil) {
		return nil, nil
	}

	if err != nil {
		logger.L().Error("redis GET error", zap.Error(err))
		return nil, err
	}

	return &value, nil
}

func (s store) set(ctx context.Context, value string, parts ...string) error {
	if err := s.rdb.Set(ctx, s.key(parts...), value, s.ttl).Err(); err != nil {
		logger.L().Error("redis SET error", zap.Error(err))
		return err
	}

	return nil
}

func (s store) del(ctx context.Context, parts ...string) error {
	if err := s.rdb.Del(ctx, s.key(parts...)).Err(); err != nil {
		logger.L().Error("redis DEL error", zap.Error(err))
		return err
	}

	return nil
}

func getJSON[T any](ctx context.Context, s store, parts ...string) (*T, error) {
	value, err := s.get(ctx, parts...)
	if err != nil || value == nil {
		return nil, err
	}

	var v T
	if err := json.Unmarshal([]byte(*value), &v); err != nil {
		logger.L().Error("json unmarshal error", zap.Error(err))
		return nil, err
	}

	return &v, nil
}

func setJSON(ctx context.Context, s store, v any, parts ...string) error {
	data, err := json.Marshal(v)
	if err != nil {
		logger.L().Error("json marshal error", zap.Error(err))
		return err
	}

	return s.set(ctx, string(data), parts...)
}
