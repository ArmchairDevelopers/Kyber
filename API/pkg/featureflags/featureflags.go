package featureflags

import (
	"encoding/json"
	"fmt"
	"net/http"
	"sync"
	"time"

	"github.com/ArmchairDevelopers/Kyber/API/pkg/logger"
	"go.uber.org/zap"
)

type Feature string

const (
	Queues  Feature = "queues"
	Parties Feature = "parties"
)

const refreshInterval = 30 * time.Second

var client = &http.Client{Timeout: 5 * time.Second}

type lightswitchEnvironment struct {
	ID       string           `json:"id"`
	Features map[Feature]bool `json:"features"`
}

type lightswitchStatus struct {
	Environments []lightswitchEnvironment `json:"environments"`
}

type Flags struct {
	url string
	env string
	mu    sync.RWMutex
	flags map[Feature]bool
}

func New(url, env string) *Flags {
	if url == "" {
		panic("LIGHTSWITCH_URL environment variable is not set")
	}
	
	if env == "" {
		panic("ENVIRONMENT environment variable is not set")
	}
	
	f := &Flags{url: url, env: env}
	f.refresh()
	
	go func() {
		for range time.Tick(refreshInterval) {
			f.refresh()
		}
	}()

	return f
}

func (f *Flags) Enabled(feature Feature) bool {
	f.mu.RLock()
	defer f.mu.RUnlock()
	
	enabled, ok := f.flags[feature]
	return !ok || enabled
}

func (f *Flags) refresh() {
	flags, err := f.fetch()
	if err != nil {
		logger.L().Warn("Failed to refresh feature flags", zap.Error(err))
		return
	}

	f.mu.Lock()
	f.flags = flags
	f.mu.Unlock()
}

func (f *Flags) fetch() (map[Feature]bool, error) {
	resp, err := client.Get(f.url)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	
	var status lightswitchStatus
	if err := json.NewDecoder(resp.Body).Decode(&status); err != nil {
		return nil, err
	}

	for _, e := range status.Environments {
		if e.ID == f.env && e.Features != nil {
			return e.Features, nil
		}
	}

	return nil, fmt.Errorf("no feature flags for environment %q", f.env)
}
