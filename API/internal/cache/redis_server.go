package cache

import (
	"context"
	"time"

	"github.com/redis/go-redis/v9"
)

const serverKeyPrefix = "server_id"

type ServerIDCache struct {
	s store
}

func NewServerIDCache(rdb *redis.Client, ttl time.Duration) *ServerIDCache {
	return &ServerIDCache{s: newStore(rdb, serverKeyPrefix, ttl)}
}

func (c *ServerIDCache) Get(ctx context.Context, serverID string) (*string, error) {
	return c.s.get(ctx, serverID)
}

func (c *ServerIDCache) Set(ctx context.Context, serverID string, hostID string) error {
	return c.s.set(ctx, hostID, serverID)
}
