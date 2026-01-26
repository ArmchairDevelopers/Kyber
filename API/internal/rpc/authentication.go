package rpc

import (
	"context"
	"crypto/rsa"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	"github.com/ArmchairDevelopers/Kyber/API/api/v1/pbapi"
	"github.com/ArmchairDevelopers/Kyber/API/api/v1/pbcommon"
	"github.com/ArmchairDevelopers/Kyber/API/api/v1/pbea"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/db"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/discord"
	ea2 "github.com/ArmchairDevelopers/Kyber/API/pkg/ea"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/logger"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/models"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/mq"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/util"
	"github.com/ArmchairDevelopers/patreon-go"
	amqp "github.com/rabbitmq/amqp091-go"
	"go.mongodb.org/mongo-driver/bson"
	"go.uber.org/zap"
	"golang.org/x/oauth2"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
)

const DayInSeconds = 86400
const EAUsernameRefreshInterval = 7 * 24 * time.Hour
const DiscordRefreshInterval = 24 * time.Hour
const EAEntitlementRefreshInterval = 48 * time.Hour

var validPatreonTiers = []string{"8197122", "8196287", "8039424"}

type whitelist struct {
	UsernameWhitelist []string `yaml:"usernameWhitelist"`
	PersonaWhitelist  []string `yaml:"personaWhitelist"`
}

type AuthenticationServer struct {
	eaJwks           map[string]*rsa.PublicKey
	store            *db.Store
	patreonClient    *patreon.Client
	patreonOAuth     *oauth2.Config
	whitelist        *whitelist
	mqClient         mq.Client
	usersClient      *pbea.UsersClient
	discordHelper    *discord.Helper
	whitelistEnabled bool
	pbapi.UnimplementedAuthenticationServer
}

func NewAuthenticationServer(ctx context.Context, store *db.Store, mqClient mq.Client) *AuthenticationServer {
	eaJwks, err := ea2.LoadJwks()
	if err != nil {
		panic(fmt.Sprintf("failed to load EA JWKS: %v", err))
	}

	whitelistEnabled := true
	if strings.ToLower(os.Getenv("WHITELIST_ENABLED")) == "false" {
		whitelistEnabled = false
	}

	accessToken := os.Getenv("PATREON_ACCESS_TOKEN")
	clientSecret := os.Getenv("PATREON_CLIENT_SECRET")
	clientID := os.Getenv("PATREON_CLIENT_ID")

	var client *patreon.Client
	var patreonOAuth oauth2.Config
	if clientSecret != "" && clientID != "" && accessToken != "" {
		ts := oauth2.StaticTokenSource(&oauth2.Token{AccessToken: accessToken})
		tc := oauth2.NewClient(ctx, ts)

		client = patreon.NewClient(tc)

		patreonOAuth = oauth2.Config{
			ClientSecret: clientSecret,
			ClientID:     clientID,
			RedirectURL:  "http://localhost:13022",
			Endpoint: oauth2.Endpoint{
				AuthURL:   "https://www.patreon.com/api/oauth2/authorize",
				TokenURL:  "https://www.patreon.com/api/oauth2/token",
				AuthStyle: oauth2.AuthStyleInParams,
			},
		}
	} else {
		logger.L().Warn("Patreon OAuth configuration is incomplete. Patreon features will be disabled.")
	}

	wl := &whitelist{}
	if err := util.LoadConfig("whitelist.yaml", wl); err != nil {
		panic(fmt.Sprintf("failed to load whitelist config: %v", err))
	}

	var usersClient *pbea.UsersClient
	eaBridgeAddr := os.Getenv("KYBER_EA_BRIDGE")
	if eaBridgeAddr != "" {
		grpcConn, err := grpc.DialContext(ctx, eaBridgeAddr,
			grpc.WithTransportCredentials(insecure.NewCredentials()),
			grpc.WithBlock(),
		)

		if err != nil {
			log.Fatalf("failed to dial gRPC server: %v", zap.Error(err))
		}

		uc := pbea.NewUsersClient(grpcConn)
		usersClient = &uc
	}

	discordHelper := discord.NewHelper()

	return &AuthenticationServer{
		eaJwks:           eaJwks,
		store:            store,
		patreonClient:    client,
		patreonOAuth:     &patreonOAuth,
		whitelist:        wl,
		mqClient:         mqClient,
		usersClient:      usersClient,
		discordHelper:    discordHelper,
		whitelistEnabled: whitelistEnabled,
	}
}

func (s *AuthenticationServer) UnlinkPatreonAccount(ctx context.Context, req *pbcommon.Empty) (*pbcommon.Empty, error) {
	if s.patreonClient == nil {
		return nil, status.Error(codes.Unimplemented, "Patreon features are not enabled")
	}

	user := ctx.Value("user").(*models.UserModel)

	if user.PatreonData == nil {
		return nil, status.Error(codes.PermissionDenied, "No Patreon account linked")
	}

	err := s.store.Users.Update(ctx, user.ID, bson.M{
		"$set": bson.M{
			"token":        util.GenerateToken(),
			"patreon_data": nil,
		},
	})
	if err != nil {
		logger.L().Error("Failed to unlink Patreon account", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to unlink Patreon account")
	}

	logger.L().Info(fmt.Sprintf("User %s (%s) unlinked their Patreon account", user.Name, user.ID))

	return &pbcommon.Empty{}, nil
}

func (s *AuthenticationServer) LinkPatreonAccount(ctx context.Context, req *pbapi.LinkPatreonAccountRequest) (*pbcommon.Empty, error) {
	if s.patreonClient == nil {
		return nil, status.Error(codes.Unimplemented, "Patreon features are not enabled")
	}

	claims, err := ea2.ValidateToken(s.eaJwks, req.GetToken())
	if err != nil {
		logger.L().Error("Failed to validate EA token", zap.Error(err))
		return nil, status.Error(codes.Unauthenticated, "Invalid EA token")
	}

	if claims.Uif.Sta != "ACTIVE" {
		return nil, status.Error(codes.PermissionDenied, "Sorry, your account is inactive. This may be due to a ban or suspension. Please contact support for assistance.")
	}

	patron, err := s.patreonClient.GetMemberByID(req.GetMembershipId(), patreon.WithFields("member", "patron_status", "email"), patreon.WithIncludes("user", "currently_entitled_tiers"), patreon.WithFields("user", "social_connections", "full_name", "email"))
	if err != nil {
		logger.L().Error(err.Error())
		return nil, status.Error(codes.Internal, "Failed to fetch Patreon data")
	}

	if patron == nil {
		return nil, status.Error(codes.PermissionDenied, "Invalid membership ID")
	}

	active, err := s.isActivePatron(patron)

	if err != nil {
		return nil, err
	}

	if !active {
		return nil, status.Error(codes.PermissionDenied, "User is not an active patron")
	}

	user, err := s.store.Users.GetByID(ctx, claims.Pid)
	if err != nil {
		logger.L().Error(err.Error())
		return nil, status.Error(codes.Internal, "Failed to get user")
	}

	if user == nil {
		return nil, status.Error(codes.PermissionDenied, "User not found")
	}

	discordConnection := patron.User.SocialConnections.Discord
	if discordConnection == nil {
		return nil, status.Error(codes.Internal, "You are a Patreon member, but you have not linked your Discord account.")
	}

	existingConnection, err := s.store.Users.GetByDiscordID(ctx, discordConnection.UserID)
	if err != nil {
		logger.L().Error(err.Error())
		return nil, status.Error(codes.Internal, "Failed to get user")
	}

	if existingConnection != nil {
		return nil, status.Error(codes.PermissionDenied, "Your Discord account is already linked to another user.")
	}

	existingUser, err := s.store.Users.GetByDoc(ctx, bson.M{"patreon_data.membership_id": patron.ID})
	if err != nil {
		logger.L().Error(err.Error())
		return nil, status.Error(codes.Internal, "Failed to check for existing Patreon account")
	}

	if existingUser != nil && existingUser.ID != user.ID {
		logger.L().Error(fmt.Sprintf("User %s (%s) tried to link Patreon account that is already linked to another user %s (%s)", user.Name, user.ID, existingUser.Name, existingUser.ID))
		return nil, status.Error(codes.PermissionDenied, fmt.Sprintf("Your Patreon account is already linked to %s. If this is an error, please contact support.", existingUser.Name))
	}

	user = &models.UserModel{
		ID: user.ID,
		PatreonData: &models.PatreonData{
			ID:           patron.User.ID,
			MembershipID: patron.ID,
			FullName:     patron.FullName,
			Email:        patron.Email,
			DiscordID:    &discordConnection.UserID,
			LastChecked:  time.Now(),
		},
		LastSeen: time.Now(),
	}

	err = s.updateDiscordData(ctx, user)
	if err != nil {
		return nil, err
	}

	err = s.store.Users.Update(ctx, user.ID, bson.M{
		"$set": bson.M{
			"patreon_data": util.ToBson(user.PatreonData),
			"last_seen":    time.Now(),
		},
	})
	if err != nil {
		logger.L().Error(err.Error())
		return nil, status.Error(codes.Internal, "Failed to update user")
	}

	logger.L().Info(fmt.Sprintf("User %s linked their Patreon account", user.Name))
	return &pbcommon.Empty{}, nil
}

func (s *AuthenticationServer) UnlinkDiscordAccount(ctx context.Context, _ *pbcommon.Empty) (*pbcommon.Empty, error) {
	user := ctx.Value("user").(*models.UserModel)

	if user.DiscordData == nil {
		return nil, status.Error(codes.PermissionDenied, "No Discord account linked")
	}

	err := s.store.Users.Update(ctx, user.ID, bson.M{
		"$set": bson.M{
			"discord_data": nil,
		},
	})
	if err != nil {
		logger.L().Error("Failed to unlink Discord account", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to unlink Discord account")
	}

	logger.L().Info(fmt.Sprintf("User %s (%s) unlinked their Discord account", user.Name, user.ID))

	return &pbcommon.Empty{}, nil
}

func (s *AuthenticationServer) PatreonLogin(ctx context.Context, req *pbapi.AuthCodeRequest) (*pbapi.UserVerificationResponse, error) {
	if s.patreonClient == nil {
		return nil, status.Error(codes.Unimplemented, "Patreon features are not enabled")
	}

	tokens, err := s.patreonOAuth.Exchange(ctx, req.GetAuthCode())
	if err != nil {
		logger.L().Error("Failed to exchange auth code", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to exchange auth code")
	}

	patreonClient := patreon.NewClient(s.patreonOAuth.Client(ctx, tokens))
	identity, err := patreonClient.GetIdentity(patreon.WithFields("user", "first_name", "last_name", "full_name", "vanity", "email", "about", "image_url", "thumb_url", "created", "url"), patreon.WithIncludes("memberships", "campaign"), patreon.WithFields("member", "campaign_lifetime_support_cents", "currently_entitled_amount_cents", "email", "full_name", "is_follower", "last_charge_date", "last_charge_status", "lifetime_support_cents", "next_charge_date", "note", "patron_status", "pledge_cadence", "pledge_relationship_start", "will_pay_amount_cents"))
	if err != nil {
		logger.L().Error("Failed to get identity", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get identity")
	}

	if len(identity.Memberships) == 0 {
		logger.L().Error(fmt.Sprintf("No memberships found for user: %s", identity.ID))
		return nil, status.Error(codes.PermissionDenied, "No active memberships found")
	}

	var membership *patreon.Member
	for _, m := range identity.Memberships {
		logger.L().Info(fmt.Sprintf("Found membership for user: %s with status %s", m.ID, m.PatronStatus))
		if m.PatronStatus == "active_patron" {
			membership = m
			break
		}
	}

	for _, m := range identity.Memberships {
		member, err := s.patreonClient.GetMemberByID(m.ID, patreon.WithIncludes("currently_entitled_tiers"))
		if err != nil {
			logger.L().Error("Failed to get latest membership", zap.Error(err))
			return nil, status.Error(codes.Internal, "Failed to get latest membership")
		}

		active, _ := s.isActivePatron(member)
		if !active {
			continue
		}

		membership = member
	}

	if membership == nil {
		logger.L().Error(fmt.Sprintf("No active membership found for user: %s", identity.ID))
		return nil, status.Error(codes.PermissionDenied, "No active memberships found")
	}

	return &pbapi.UserVerificationResponse{
		MembershipId: membership.ID,
		UserId:       identity.ID,
		TokenInfo: &pbapi.TokenInfo{
			AccessToken:  tokens.AccessToken,
			RefreshToken: tokens.RefreshToken,
			Scope:        "",
			ExpiresIn:    uint64(tokens.ExpiresIn),
			TokenType:    tokens.TokenType,
			Version:      "0",
		},
	}, nil
}

func (s *AuthenticationServer) Verify(ctx context.Context, _ *pbcommon.Empty) (*pbapi.VerifyResponse, error) {
	user := ctx.Value("user").(*models.UserModel)

	punishment, err := s.store.Punishments.GetGlobalBan(ctx, user.ID)
	if err != nil {
		logger.L().Error(err.Error())
		return nil, status.Error(codes.Internal, "Failed to get punishment")
	}

	if punishment != nil && punishment.IsActive() {
		return nil, status.Error(codes.PermissionDenied, punishment.BanMessage())
	}

	return &pbapi.VerifyResponse{
		Id:      user.ID,
		Name:    user.Name,
		Discord: user.ConvDiscordData(),
	}, nil
}

func (s *AuthenticationServer) ResetToken(ctx context.Context, _ *pbcommon.Empty) (*pbcommon.Empty, error) {
	user := ctx.Value("user").(*models.UserModel)

	token := util.GenerateToken()

	err := s.store.Users.Update(ctx, user.ID, bson.M{"$set": bson.M{"token": token}})
	if err != nil {
		logger.L().Error("Failed to update user token", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to reset token")
	}

	return &pbcommon.Empty{}, nil
}

func (s *AuthenticationServer) Login(ctx context.Context, req *pbapi.LoginRequest) (*pbapi.LoginResponse, error) {
	meta, exist := metadata.FromIncomingContext(ctx)
	if !exist {
		return nil, status.Error(codes.Unauthenticated, "Missing metadata")
	}

	addr := meta.Get("cf-connecting-ip")
	if len(addr) == 0 {
		return nil, status.Error(codes.Internal, "Invalid Request")
	}

	userIP := addr[0]

	claims, err := ea2.ValidateToken(s.eaJwks, req.GetToken())
	if err != nil {
		logger.L().Error(err.Error())
		return nil, status.Error(codes.Internal, "Failed to validate token")
	}

	if claims.Uif.Sta != "ACTIVE" {
		return nil, status.Error(codes.PermissionDenied, "Sorry, your account is inactive. This may be due to a ban or suspension. Please contact support for assistance.")
	}

	personaInfo := claims.PersonaInfo()
	if personaInfo == nil {
		return nil, status.Error(codes.PermissionDenied, "No persona information found. Please contact support!")
	}

	user, err := s.store.Users.GetByID(ctx, claims.Pid)
	if err != nil {
		logger.L().Error(err.Error())
		return nil, status.Error(codes.Internal, "Failed to get user")
	}

	punishment, err := s.store.Punishments.GetGlobalBan(ctx, claims.Pid)
	if err != nil {
		logger.L().Error(err.Error())
		return nil, status.Error(codes.Internal, "Failed to get punishment")
	}

	if user != nil {
		user.UpsertIP(userIP)
		user.PruneIPs(6)
		user.EAData.UpsertDevice(claims.Dvid)

		err = s.updateUserName(ctx, user, personaInfo)
		if err != nil {
			logger.L().Error(err.Error())
			return nil, status.Error(codes.Internal, "Failed to update user information. Please contact support.")
		}

		err = s.store.Users.Update(
			ctx,
			user.ID,
			bson.M{
				"$inc": bson.M{"metric_data.login_count": 1},
				"$set": bson.M{
					"last_seen":            time.Now(),
					"ips":                  user.IPs,
					"ea_data.device_ids":   user.EAData.DeviceIDs,
					"ea_data.display_name": user.EAData.DisplayName,
					"ea_data.last_updated": user.EAData.LastUpdated,
					"name":                 user.Name,
				},
			},
		)

		if err != nil {
			logger.L().Error(err.Error())
			return nil, status.Error(codes.Internal, "Failed to update user. Please contact support.")
		}
	}

	if punishment != nil && punishment.IsActive() {
		return nil, status.Error(codes.PermissionDenied, punishment.BanMessage())
	}

	if user == nil {
		user, err = s.store.Users.Create(ctx, *personaInfo, *claims, userIP)
		if err != nil {
			logger.L().Error(err.Error())
			return nil, status.Error(codes.Internal, "Failed to create user. Please contact support.")
		}

		isVPN, err := s.checkVPNBlock(user, userIP)
		if err != nil {
			logger.L().Warn(fmt.Sprintf("Failed to check VPN for IP %s: %v", userIP, err))
			isVPN = false
		}

		if isVPN {
			logger.L().Info(fmt.Sprintf("Created new user with VPN detected: %s (%s) from IP %s", user.Name, user.ID, userIP))
		} else {
			logger.L().Info(fmt.Sprintf("Created new user: %s (%s)", user.Name, user.ID))
		}
	}

	if user.VPNBlocked {
		return nil, status.Error(codes.PermissionDenied, "We detected malicious activity from your connection. Please disable any VPN or proxy and try again. If you believe this is an error, please contact support.")
	}

	s.publishPlayerLoggedIn(*user)

	err = s.updatePatreonData(ctx, user)
	if err != nil {
		logger.L().Error(err.Error())
	}

	whitelisted := user.Entitled(models.EntitlementWhitelisted) ||
		user.IsPatron() ||
		containsIgnoreCase(s.whitelist.PersonaWhitelist, user.EAData.PersonaID)

	if !whitelisted && s.whitelistEnabled {
		return nil, status.Error(codes.PermissionDenied, "You are not whitelisted for the KYBER V2 playtest. If you are a Patreon supporter, please link your account. Please contact support if you think this is an error.")
	}

	if user.EAData.LastEntitlementCheck == nil || time.Since(*user.EAData.LastEntitlementCheck) > EAEntitlementRefreshInterval {
		isBanned, err := ea2.IsBanned(req.GetToken())
		if err != nil {
			logger.L().Error(err.Error())
			return nil, status.Error(codes.Internal, "Failed to check EA entitlements")
		}

		user.EAData.IsBanned = isBanned
		user.EAData.LastEntitlementCheck = util.ToPtr(time.Now())
		err = s.store.Users.Update(ctx, user.ID, bson.M{
			"$set": bson.M{
				"ea_data.is_banned":              user.EAData.IsBanned,
				"ea_data.last_entitlement_check": user.EAData.LastEntitlementCheck,
			},
		})
		if err != nil {
			logger.L().Error(err.Error())
			return nil, status.Error(codes.Internal, "Failed to update EA entitlements")
		}
	}

	if user.EAData.IsBanned {
		logger.L().Info("User tried to login but is banned", zap.String("userID", user.ID), zap.String("userName", user.Name))
		return nil, status.Error(codes.PermissionDenied, "There was an issue verifying your EA account status for Battlefront 2. Please contact EA Support for more information.")
	}

	err = s.updateDiscordData(ctx, user)
	if err != nil {
		logger.L().Error(err.Error())
		return nil, status.Error(codes.Internal, "Failed to update Discord data")
	}

	logger.L().Info(fmt.Sprintf("User %s (%s) logged in", personaInfo.Dis, user.ID))
	return &pbapi.LoginResponse{
		Id:           user.ID,
		Name:         user.Name,
		Token:        user.Token,
		Entitlements: user.ConvEntitlements(),
		IsPatreon:    user.IsPatron(),
		Discord:      user.ConvDiscordData(),
	}, nil
}

func (s *AuthenticationServer) checkVPNBlock(user *models.UserModel, userIP string) (bool, error) {
	isVPN, err := util.IsVPN(userIP)
	if err != nil {
		logger.L().Warn(fmt.Sprintf("Failed to check VPN for IP %s: %v", userIP, err))
		return false, err
	}

	if isVPN && !user.VPNBlocked {
		user.VPNBlocked = true
	}

	err = s.store.Users.Update(context.Background(), user.ID, bson.M{
		"$set": bson.M{
			"vpn_blocked": user.VPNBlocked,
		},
	})

	return isVPN, err
}

func (s *AuthenticationServer) updateDiscordData(ctx context.Context, user *models.UserModel) error {
	if s.discordHelper == nil {
		return nil
	}

	var userId string
	if user.DiscordData != nil {
		if time.Since(user.DiscordData.LastUpdated) < DiscordRefreshInterval {
			return nil
		}

		userId = user.DiscordData.ID
	} else if user.PatreonData != nil && user.PatreonData.DiscordID != nil {
		userId = *user.PatreonData.DiscordID
	}

	if userId == "" {
		return nil
	}

	member, err := s.discordHelper.FetchUser(userId)
	if err != nil {
		logger.L().Error(err.Error())
		return nil
	}

	if member == nil {
		user.DiscordData = nil
		return nil
	}

	user.DiscordData = s.discordHelper.GenerateUserData(member)

	err = s.store.Users.Update(ctx, user.ID, bson.M{
		"$set": bson.M{
			"discord_data": user.DiscordData,
		},
	})

	return err
}

func (s *AuthenticationServer) isActivePatron(membership *patreon.Member) (bool, error) {
	if membership == nil {
		return false, status.Error(codes.PermissionDenied, "No active Patreon membership found.")
	}

	tiers := membership.CurrentlyEntitledTiers
	hasValidTier := false

	for _, tier := range tiers {
		for _, validTierID := range validPatreonTiers {
			if tier.ID == validTierID {
				hasValidTier = true
				break
			}
		}
	}

	if !hasValidTier {
		return false, status.Error(codes.PermissionDenied, "You must be subscribed to a valid Patreon tier to access this feature.")
	}

	return true, nil
}

func (s *AuthenticationServer) updateUserName(ctx context.Context, user *models.UserModel, personaInfo *ea2.JwtUserPersonaInformationClaims) error {
	if s.usersClient == nil && personaInfo.Dis != user.Name {
		logger.L().Info(fmt.Sprintf("User (name: %s, id: %s) changed their display name to %s", user.Name, user.ID, personaInfo.Dis))

		user.EAData.DisplayName = personaInfo.Dis

		if !user.Entitled(models.EntitlementDisableNameSync) {
			user.Name = personaInfo.Dis
		}

		return nil
	}

	if s.usersClient == nil {
		return nil
	}

	if user.EAData.LastUpdated != nil && time.Since(*user.EAData.LastUpdated) < EAUsernameRefreshInterval {
		return nil
	}

	userResp, err := (*s.usersClient).SearchUser(ctx, &pbea.EaUserPdSearchRequest{PersonaId: user.ID})
	if err != nil {
		return err
	}

	if userResp == nil {
		return status.Error(codes.Internal, "Failed to get user information")
	}

	if userResp.GetDisplayName() != user.Name {
		logger.L().Info(fmt.Sprintf("User (name: %s, id: %s) changed their display name to %s", user.Name, user.ID, userResp.GetDisplayName()))

		if err := s.updateExistingUser(ctx, userResp.GetDisplayName()); err != nil {
			return err
		}

		user.EAData.DisplayName = userResp.GetDisplayName()

		if !user.Entitled(models.EntitlementDisableNameSync) {
			user.Name = userResp.GetDisplayName()
		}
	}

	now := time.Now()
	user.EAData.LastUpdated = &now

	return nil
}

func (s *AuthenticationServer) updateExistingUser(ctx context.Context, name string) error {
	if s.usersClient == nil {
		return nil
	}

	existingUser, err := s.store.Users.SearchByName(ctx, name)
	if err != nil {
		return err
	}

	if existingUser != nil {
		userInfo, err := (*s.usersClient).SearchUser(ctx, &pbea.EaUserPdSearchRequest{PersonaId: existingUser.ID})
		if err != nil {
			return err
		}

		if userInfo == nil {
			return status.Error(codes.Internal, "Failed to get user information")
		}

		err = s.store.Users.Update(ctx, existingUser.ID, bson.M{
			"$set": bson.M{
				"name":                 userInfo.DisplayName,
				"ea_data.display_name": userInfo.DisplayName,
				"ea_data.last_updated": time.Now(),
			},
		})

		if err != nil {
			return err
		}
	}

	return nil
}

func (s *AuthenticationServer) updatePatreonData(ctx context.Context, user *models.UserModel) error {
	if s.patreonClient == nil || user.PatreonData == nil {
		return nil
	}

	lastChecked := user.PatreonData.LastChecked
	diff := time.Since(lastChecked)

	if diff.Seconds() > float64(DayInSeconds) {
		membership, err := s.patreonClient.GetMemberByID(user.PatreonData.MembershipID, patreon.WithFields("member", "campaign_lifetime_support_cents", "currently_entitled_amount_cents", "email", "full_name", "is_follower", "last_charge_date", "last_charge_status", "lifetime_support_cents", "next_charge_date", "note", "patron_status", "pledge_cadence", "pledge_relationship_start", "will_pay_amount_cents"), patreon.WithIncludes("user", "currently_entitled_tiers"), patreon.WithFields("user", "social_connections"))
		if err != nil {
			user.PatreonData = nil
			logger.L().Error(fmt.Sprintf("Failed to get patreon data: %v", err))
			return status.Error(codes.Internal, "Failed to fetch Patreon data")
		}

		active, err := s.isActivePatron(membership)
		if err == nil && active {
			discordLinked := membership.User.SocialConnections.Discord != nil

			if !discordLinked {
				logger.L().Warn(fmt.Sprintf("User %s (%s) Patreon account has no linked Discord", user.Name, user.ID))
			}

			var patreonData *models.PatreonData
			if active && discordLinked {
				patreonData = &models.PatreonData{
					ID:           membership.User.ID,
					MembershipID: membership.ID,
					FullName:     membership.FullName,
					Email:        membership.Email,
					DiscordID:    &membership.User.SocialConnections.Discord.UserID,
					LastChecked:  time.Now(),
				}
			}

			err = s.store.Users.Update(ctx, user.ID, bson.M{"$set": bson.M{"patreon_data": util.ToBson(patreonData)}})
			if err != nil {
				return status.Error(codes.Internal, "Failed to update user")
			}
		} else if err != nil {
			logger.L().Error(fmt.Sprintf("Failed to validate Patreon membership: %v", err))
		}
	}

	return nil
}

func containsIgnoreCase(slice []string, target string) bool {
	for _, s := range slice {
		if strings.EqualFold(s, target) {
			return true
		}
	}
	return false
}

func (s *AuthenticationServer) publishPlayerLoggedIn(user models.UserModel) {
	body, err := json.Marshal(user)
	if err != nil {
		logger.L().Error(err.Error())
		return
	}

	err = s.mqClient.Channel.Publish(
		"player_events",
		"player.connected",
		false,
		false,
		amqp.Publishing{
			ContentType: "application/json",
			Body:        body,
		},
	)
	if err != nil {
		logger.L().Error(err.Error())
	}
}
