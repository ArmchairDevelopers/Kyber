package api

import (
	"context"
	"encoding/json"
	"fmt"
	"math/rand"
	"net/http"
	"os"
	"sync"
	"time"

	"github.com/ArmchairDevelopers/Kyber/API/internal/cache"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/db"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/discord"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/logger"
	"github.com/bwmarrin/discordgo"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.uber.org/zap"
	"golang.org/x/oauth2"
)

type DiscordAuthState struct {
	store         *db.Store
	discordHelper *discord.Helper
	discordOAuth  *oauth2.Config
	stateStore    *cache.DiscordAuthCache
	stateMu       sync.RWMutex
}

func NewDiscordAuthState(store *db.Store, discordCache *cache.DiscordAuthCache) *DiscordAuthState {
	discordClientID := os.Getenv("DISCORD_CLIENT_ID")
	discordClientSecret := os.Getenv("DISCORD_CLIENT_SECRET")
	discordRedirectURL := os.Getenv("DISCORD_REDIRECT_URL")
	if discordRedirectURL == "" {
		discordRedirectURL = "http://localhost:13023/discord/callback"
	}

	var discordOAuth *oauth2.Config
	if discordClientSecret != "" && discordClientID != "" {
		discordOAuth = &oauth2.Config{
			ClientID:     discordClientID,
			ClientSecret: discordClientSecret,
			RedirectURL:  discordRedirectURL,
			Scopes:       []string{"identify"},
			Endpoint: oauth2.Endpoint{
				AuthURL:  "https://discord.com/api/oauth2/authorize",
				TokenURL: "https://discord.com/api/oauth2/token",
			},
		}
	}

	return &DiscordAuthState{
		store:        store,
		discordOAuth: discordOAuth,
		stateStore:   discordCache,
	}
}

func (s *DiscordAuthState) AuthHandler(w http.ResponseWriter, r *http.Request) {
	if s.discordOAuth == nil {
		http.Error(w, "Discord OAuth is not configured", http.StatusServiceUnavailable)
		return
	}

	token := r.URL.Query().Get("token")
	if token == "" {
		token = r.Header.Get("Authorization")
	}

	if token == "" {
		http.Error(w, "Authentication token required", http.StatusUnauthorized)
		return
	}

	user, err := s.store.Users.GetByToken(r.Context(), token)
	if err != nil {
		logger.L().Error("Failed to get user by token", zap.Error(err))
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	if user == nil {
		http.Error(w, "Invalid token", http.StatusUnauthorized)
		return
	}

	state := randStringBytes(32)

	s.stateMu.Lock()
	defer s.stateMu.Unlock()
	err = s.stateStore.Set(r.Context(), state, user.ID)
	if err != nil {
		logger.L().Error("Failed to store Discord auth state", zap.Error(err))
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	url := s.discordOAuth.AuthCodeURL(state, oauth2.AccessTypeOnline)
	http.Redirect(w, r, url, http.StatusTemporaryRedirect)
}

func (s *DiscordAuthState) CallbackHandler(w http.ResponseWriter, r *http.Request) {
	if s.discordOAuth == nil {
		http.Error(w, "Discord OAuth is not configured", http.StatusServiceUnavailable)
		return
	}

	state := r.URL.Query().Get("state")
	code := r.URL.Query().Get("code")

	if state == "" || code == "" {
		http.Error(w, "Missing state or code parameter", http.StatusBadRequest)
		return
	}

	logger.L().Info("Discord OAuth callback received", zap.String("state", state))

	s.stateMu.Lock()
	entry, err := s.stateStore.Get(r.Context(), state)
	s.stateMu.Unlock()

	if err != nil {
		logger.L().Error("Failed to get state from store", zap.Error(err))
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	if entry == nil {
		http.Error(w, "Invalid state parameter", http.StatusBadRequest)
		return
	}

	user, err := s.store.Users.GetByID(r.Context(), *entry)
	if err != nil {
		logger.L().Error("Failed to get user by token", zap.Error(err))
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	if user == nil {
		http.Error(w, "User not found", http.StatusUnauthorized)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 10*time.Second)
	defer cancel()

	tokens, err := s.discordOAuth.Exchange(ctx, code)
	if err != nil {
		logger.L().Error("Failed to exchange Discord auth code", zap.Error(err))
		http.Error(w, "Failed to exchange auth code", http.StatusInternalServerError)
		return
	}

	client := s.discordOAuth.Client(ctx, tokens)
	resp, err := client.Get("https://discord.com/api/v10/users/@me")
	if err != nil {
		logger.L().Error("Failed to get Discord user info", zap.Error(err))
		http.Error(w, "Failed to get Discord user information", http.StatusInternalServerError)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		logger.L().Error(fmt.Sprintf("Discord API returned status %d", resp.StatusCode))
		http.Error(w, "Failed to get Discord user information", http.StatusInternalServerError)
		return
	}

	var discordUser discordgo.User
	if err := json.NewDecoder(resp.Body).Decode(&discordUser); err != nil {
		logger.L().Error("Failed to decode Discord user response", zap.Error(err))
		http.Error(w, "Failed to parse Discord user information", http.StatusInternalServerError)
		return
	}

	existingUser, err := s.store.Users.GetByDiscordID(r.Context(), discordUser.ID)
	if err != nil {
		logger.L().Error("Failed to check for existing Discord account", zap.Error(err))
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	if existingUser != nil && existingUser.ID != user.ID {
		logger.L().Warn(fmt.Sprintf("User %s (%s) tried to link Discord account that is already linked to another user %s (%s)", user.Name, user.ID, existingUser.Name, existingUser.ID))
		http.Error(w, fmt.Sprintf("This Discord account is already linked to %s. If this is an error, please contact support.", existingUser.Name), http.StatusConflict)
		return
	}

	data := s.discordHelper.GenerateUserData(&discordUser)
	err = s.store.Users.Update(r.Context(), user.ID, bson.M{
		"$set": bson.M{
			"discord_data": &data,
			"last_seen":    time.Now(),
		},
	})
	if err != nil {
		logger.L().Error("Failed to update user with Discord ID", zap.Error(err))
		http.Error(w, "Failed to update user", http.StatusInternalServerError)
		return
	}

	logger.L().Info(fmt.Sprintf("User %s (%s) linked their Discord account", user.Name, user.ID))

	http.Redirect(w, r, "kl://discord_linked", http.StatusSeeOther)
}

const letterBytes = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

func randStringBytes(n int) string {
	b := make([]byte, n)
	for i := range b {
		b[i] = letterBytes[rand.Intn(len(letterBytes))]
	}
	return string(b)
}
