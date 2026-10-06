package cache

import (
	"context"
	"time"

	"github.com/redis/go-redis/v9"
)

const discordAuthKeyPrefix = "discord_auth"

type DiscordAuthCache struct {
	s store
}

func NewDiscordAuthCache(rdb *redis.Client, ttl time.Duration) *DiscordAuthCache {
	return &DiscordAuthCache{s: newStore(rdb, discordAuthKeyPrefix, ttl)}
}

func (c *DiscordAuthCache) Get(ctx context.Context, state string) (*string, error) {
	return c.s.get(ctx, state)
}

func (c *DiscordAuthCache) Set(ctx context.Context, state string, token string) error {
	return c.s.set(ctx, token, state)
}
