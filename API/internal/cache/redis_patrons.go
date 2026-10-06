package cache

import (
	"context"
	"time"

	"github.com/redis/go-redis/v9"
)

const patronListKeyPrefix = "patron_list"

type PatronsCache struct {
	s store
}

func NewPatronsCache(rdb *redis.Client, ttl time.Duration) *PatronsCache {
	return &PatronsCache{s: newStore(rdb, patronListKeyPrefix, ttl)}
}

func (c *PatronsCache) Get(ctx context.Context) (*[]string, error) {
	return getJSON[[]string](ctx, c.s)
}

func (c *PatronsCache) Set(ctx context.Context, m *[]string) error {
	return setJSON(ctx, c.s, m)
}
