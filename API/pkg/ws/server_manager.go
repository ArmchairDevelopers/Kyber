package ws

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"sync"
	"time"

	"github.com/ArmchairDevelopers/Kyber/API/pkg/db"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/logger"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/util"
	"go.uber.org/zap"

	"github.com/ArmchairDevelopers/Kyber/API/api/v1/pbapi"
	"github.com/ArmchairDevelopers/Kyber/API/api/v1/pbcommon"
	"github.com/gorilla/mux"
	"github.com/gorilla/websocket"
	amqp "github.com/rabbitmq/amqp091-go"
	"go.mongodb.org/mongo-driver/bson"
	"google.golang.org/protobuf/proto"
)

type OwnedServer struct {
	Conn    *websocket.Conn
	Players []*pbcommon.ServerPlayer
}

type OwnedClient struct {
	Conn         *websocket.Conn
	IsModerator  bool
	ConnectionID string
}

type ServerManager struct {
	ownedServers   map[string]*OwnedServer
	ownedClients   map[string]map[string]*OwnedClient
	playerCache    map[string][]*pbcommon.ServerPlayer
	amqpConn       *amqp.Connection
	amqpChannel    *amqp.Channel
	exchangeName   string
	exchangeType   string
	subscriberDone chan bool
	ctx            context.Context
	mu             sync.RWMutex
	store          *db.Store
}

func NewServerManager(ctx context.Context, amqpURL string, store *db.Store) *ServerManager {
	conn, err := amqp.Dial(amqpURL)
	if err != nil {
		logger.L().Panic("Failed to connect to RabbitMQ:", zap.Error(err))
	}
	ch, err := conn.Channel()
	if err != nil {
		logger.L().Panic("Failed to open a channel:", zap.Error(err))
	}

	ex := "server_state"
	if err := ch.ExchangeDeclare(ex, "topic", true, false, false, false, nil); err != nil {
		logger.L().Panic("Failed to declare exchange:", zap.Error(err))
	}

	mgr := &ServerManager{
		ownedServers:   make(map[string]*OwnedServer),
		ownedClients:   make(map[string]map[string]*OwnedClient),
		playerCache:    make(map[string][]*pbcommon.ServerPlayer),
		amqpConn:       conn,
		amqpChannel:    ch,
		exchangeName:   ex,
		exchangeType:   "topic",
		subscriberDone: make(chan bool),
		ctx:            ctx,
		store:          store,
	}
	go mgr.rabbitSubscriber()
	return mgr
}

func (sm *ServerManager) KickUserGlobally(ctx context.Context, userID string) error {
	servers, err := sm.store.Servers.GetAll(ctx)
	if err != nil {
		logger.L().Error("Failed to get all servers:", zap.Error(err))
		return err
	}

	for _, server := range servers {
		req := NewReqKickPlayer(userID, "You have been kicked from the server")
		msg := APIManagementMessage{
			ServerID: server.ID,
			Request:  &req,
		}
		sm.PublishWS(msg, server.ID)
	}

	return nil
}

func (sm *ServerManager) publishProto(msg proto.Message, routingKey string) {
	data, err := proto.Marshal(msg)
	if err != nil {
		logger.L().Error("Failed to marshal proto message:", zap.Error(err))
		return
	}
	if err := sm.amqpChannel.Publish(
		sm.exchangeName, routingKey, false, false,
		amqp.Publishing{ContentType: "application/json", Body: data, Expiration: strconv.FormatInt(int64(2*time.Minute), 10)},
	); err != nil {
		logger.L().Error("Failed to publish proto message:", zap.Error(err))
	}
}

func (sm *ServerManager) PublishWS(msg APIManagementMessage, routingKey string) {
	data, err := json.Marshal(msg)
	if err != nil {
		logger.L().Error("Failed to marshal WS message:", zap.Error(err))
		return
	}

	logger.L().Debug(fmt.Sprintf("Publishing message: %s", data))

	if err := sm.amqpChannel.Publish(
		sm.exchangeName, routingKey, false, false,
		amqp.Publishing{ContentType: "application/json", Body: data, Expiration: strconv.FormatInt(int64(2*time.Minute), 10)},
	); err != nil {
		logger.L().Error("Failed to publish WS message:", zap.Error(err))
	}
}

func (sm *ServerManager) rabbitSubscriber() {
	q, err := sm.amqpChannel.QueueDeclare("", false, true, true, false, nil)
	if err != nil {
		logger.L().Error("Failed to declare queue:", zap.Error(err))
		return
	}
	if err := sm.amqpChannel.QueueBind(q.Name, "#", sm.exchangeName, false, nil); err != nil {
		logger.L().Error("Failed to bind queue:", zap.Error(err))
		return
	}
	msgs, err := sm.amqpChannel.Consume(q.Name, "", true, true, false, false, nil)
	if err != nil {
		logger.L().Error("Failed to register consumer:", zap.Error(err))
		return
	}

	for {
		select {
		case d := <-msgs:
			if d.Body == nil {
				panic("Disconnected from AMQP")
				return
			}

			logger.L().Debug(fmt.Sprintf("Received message: %s", d.Body))
			var msg APIManagementMessage
			if err := msg.UnmarshalJSON(d.Body); err == nil {
				if msg.Request != nil {
					if msg.Request.RunCommand != "" {
						ev := &pbapi.ServerAPIEvent{
							Body: &pbapi.ServerAPIEvent_ServerRunCommand{
								ServerRunCommand: &pbapi.ServerRunCommandEvent{
									Command: msg.Request.RunCommand,
								},
							},
						}

						sm.processServerEvent(msg.ServerID, ev)
						continue
					} else if msg.Request.KickPlayer != nil {
						ev := &pbapi.ServerAPIEvent{
							Body: &pbapi.ServerAPIEvent_ServerKick{
								ServerKick: &pbapi.ServerKickPlayerEvent{
									Id:     msg.Request.KickPlayer.UserID,
									Reason: msg.Request.KickPlayer.Reason,
								},
							},
						}

						sm.processServerEvent(msg.ServerID, ev)
						continue
					} else if msg.Request.PlayerList {
						sm.mu.RLock()
						if srv, ok := sm.ownedServers[msg.ServerID]; ok {
							cnvPlayers := make([]ServerPlayerModel, len(srv.Players))
							for i, p := range srv.Players {
								cnvPlayers[i] = ServerPlayerModel{
									Name:   p.Name,
									ID:     p.Id,
									TeamID: p.TeamId,
								}
							}

							ev := &APIManagementMessage{
								ServerID: msg.ServerID,
								Status: &ServerStatusMessage{
									Players: &cnvPlayers,
								},
							}

							data, _ := ev.MarshalJSON()
							if err := sm.amqpChannel.Publish(
								sm.exchangeName, msg.ServerID, false, false,
								amqp.Publishing{ContentType: "application/json", Body: data},
							); err != nil {
								logger.L().Error("Failed to publish players message:", zap.Error(err))
							}
						}
						sm.mu.RUnlock()
						continue
					}
				} else if msg.Status != nil {
					if msg.Status.ConsoleMessage != nil {
						message := pbapi.ServerManagementAPIEvent{
							Body: &pbapi.ServerManagementAPIEvent_Console{
								Console: &pbapi.ServerManagementConsoleEvent{
									Message: msg.Status.ConsoleMessage.Message,
									Public:  &msg.Status.ConsoleMessage.IsPublic,
								},
							},
						}

						sm.processClientEvent(msg.ServerID, &message)
					} else if msg.Status.Players != nil {
						players := make([]*pbcommon.ServerPlayer, len(*msg.Status.Players))
						for i, p := range *msg.Status.Players {
							players[i] = &pbcommon.ServerPlayer{
								Name:   p.Name,
								Id:     p.ID,
								TeamId: p.TeamID,
							}
						}

						message := pbapi.ServerManagementAPIEvent{
							Body: &pbapi.ServerManagementAPIEvent_Players{
								Players: &pbapi.ServerManagementPlayersEvent{
									Players: players,
								},
							},
						}

						sm.mu.Lock()
						sm.playerCache[msg.ServerID] = players
						sm.mu.Unlock()

						sm.processClientEvent(msg.ServerID, &message)
						continue
					}
				} else if msg.Status.Stale {
					sm.mu.Lock()
					if srv, ok := sm.ownedServers[msg.ServerID]; ok {
						if err := srv.Conn.WriteMessage(websocket.CloseMessage, websocket.FormatCloseMessage(websocket.CloseNormalClosure, "Server stopped")); err != nil {
							logger.L().Error("Failed to close server connection:", zap.Error(err))
						}

						delete(sm.ownedServers, msg.ServerID)
					}

					if clients, ok := sm.ownedClients[msg.ServerID]; ok {
						for connID, client := range clients {
							if err := client.Conn.WriteMessage(websocket.CloseMessage, websocket.FormatCloseMessage(websocket.CloseNormalClosure, "Server stopped")); err != nil {
								logger.L().Error("Failed to close client connection:", zap.Error(err))
							}

							delete(clients, connID)
						}
					}

					if _, ok := sm.playerCache[msg.ServerID]; ok {
						delete(sm.playerCache, msg.ServerID)
					}

					sm.mu.Unlock()
				}
			} else {
				logger.L().Error("Failed to unmarshal message:", zap.Error(err), zap.String("body", string(d.Body)))
			}
		case <-sm.subscriberDone:
			return
		}
	}
}

func (sm *ServerManager) processServerEvent(id string, evt *pbapi.ServerAPIEvent) {
	out, _ := proto.Marshal(evt)
	sm.mu.RLock()
	if srv := sm.ownedServers[id]; srv != nil {
		if err := srv.Conn.WriteMessage(websocket.BinaryMessage, out); err != nil {
			logger.L().Error("Failed to write server event to websocket:", zap.Error(err))
			sm.mu.RUnlock()
			return
		}
	}
	sm.mu.RUnlock()
}

func (sm *ServerManager) processClientEvent(id string, evt *pbapi.ServerManagementAPIEvent) {
	out, _ := proto.Marshal(evt)
	sm.mu.RLock()
	if clients, ok := sm.ownedClients[id]; ok {
		for _, client := range clients {
			if evt.GetConsole() != nil && evt.GetConsole().GetMessage() != "" {
				if !client.IsModerator && !evt.GetConsole().GetPublic() {
					continue
				}
			}

			if err := client.Conn.WriteMessage(websocket.BinaryMessage, out); err != nil {
				logger.L().Error("Failed to write client event to websocket:", zap.Error(err))
			}
		}
	}
	sm.mu.RUnlock()
}

func (sm *ServerManager) PublishConsoleMessage(serverID string, message string, public bool) {
	status := NewStatusConsole(&ConsoleMessageModel{
		Message:  message,
		IsPublic: public,
	})
	msg := APIManagementMessage{
		ServerID: serverID,
		Status:   &status,
	}
	sm.PublishWS(msg, serverID)
}

func (sm *ServerManager) RunCommand(serverID string, command string) {
	req := NewReqRunCommand(command)
	msg := APIManagementMessage{
		ServerID: serverID,
		Request:  &req,
	}
	sm.PublishWS(msg, serverID)
}

func (sm *ServerManager) KickPlayer(serverID string, userID string, reason string) {
	req := NewReqKickPlayer(userID, reason)
	msg := APIManagementMessage{
		ServerID: serverID,
		Request:  &req,
	}
	sm.PublishWS(msg, serverID)
}

func (sm *ServerManager) RequestPlayers(serverID string) {
	req := NewReqPlayerList()
	msg := APIManagementMessage{
		ServerID: serverID,
		Request:  &req,
	}
	sm.PublishWS(msg, serverID)
}

var upgrader = websocket.Upgrader{CheckOrigin: func(r *http.Request) bool { return true }}

const (
	keepAliveTimeout = 30 * time.Second
	maxMessageSize   = 2 * 1024 * 1024
)

func (sm *ServerManager) HandleServerWS(w http.ResponseWriter, r *http.Request) {
	id := mux.Vars(r)["id"]

	token := r.Header.Get("Authorization")
	if token == "" {
		http.Error(w, "Missing token", http.StatusBadRequest)
		return
	}

	user, err := sm.store.Users.GetByToken(r.Context(), token)
	if err != nil {
		logger.L().Error("Failed to get user by token:", zap.Error(err))
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	if user == nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	server, err := sm.store.Servers.GetByID(r.Context(), id)
	if err != nil {
		logger.L().Error("Failed to get server by ID:", zap.Error(err))
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	if server == nil {
		http.Error(w, "Server not found", http.StatusGone)
		return
	}

	if user.ID != server.HostID {
		http.Error(w, "Forbidden", http.StatusForbidden)
		return
	}

	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		logger.L().Error("Failed to upgrade connection:", zap.Error(err))
		return
	}

	conn.SetReadLimit(maxMessageSize)
	conn.SetReadDeadline(time.Now().Add(keepAliveTimeout + 10*time.Second))

	connCtx, cancel := context.WithCancel(context.Background())
	conn.SetCloseHandler(func(code int, text string) error {
		cancel()
		return nil
	})

	sm.mu.Lock()
	if sm.ownedServers[id] != nil {
		logger.L().Info("Server already owned, closing existing connection", zap.String("server_id", id))
		if err := sm.ownedServers[id].Conn.WriteMessage(websocket.CloseMessage, websocket.FormatCloseMessage(websocket.CloseNormalClosure, "Server already owned")); err != nil {
			logger.L().Error("Failed to close existing server connection:", zap.Error(err))
		}

		delete(sm.ownedServers, id)
	}

	sm.ownedServers[id] = &OwnedServer{Conn: conn}
	sm.mu.Unlock()

	go func() {
		defer func() {
			logger.L().Info("read-loop exiting, cleaning up", zap.String("server_id", id))
			sm.mu.Lock()
			delete(sm.ownedServers, id)
			sm.mu.Unlock()

			ctx, cancelUpdate := context.WithTimeout(context.Background(), 5*time.Second)
			defer cancelUpdate()
			sm.store.Servers.UpdateByID(ctx, id, bson.M{"$set": bson.M{"last_updated": time.Now()}})

			conn.Close()
		}()

		for {
			select {
			case <-connCtx.Done():
				return
			default:
			}

			_, msgBytes, err := conn.ReadMessage()
			if err != nil {
				if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
					logger.L().Error("WebSocket read error:", zap.Error(err))
				}
				return
			}

			err = conn.SetReadDeadline(time.Now().Add(keepAliveTimeout + 10*time.Second))
			if err != nil {
				logger.L().Error("Failed to set read deadline:", zap.Error(err))
				return
			}

			if len(msgBytes) == 0 {
				continue
			}

			var evt pbapi.ServerManagementAPIEvent
			if err := proto.Unmarshal(msgBytes, &evt); err != nil {
				logger.L().Debug("Failed to unmarshal message", zap.Error(err))
				continue
			}

			updateCtx, updateCancel := context.WithTimeout(context.Background(), 5*time.Second)

			if err := sm.store.Servers.UpdateByID(updateCtx, server.ID, bson.M{"$set": bson.M{"last_updated": time.Now()}}); err != nil {
				logger.L().Error("Failed to update server last updated time", zap.Error(err))
				updateCancel()
				return
			}
			updateCancel()

			if err := sm.processServerSocketEvent(id, &evt); err != nil {
				logger.L().Error("Failed to process server event", zap.Error(err))
			}
		}
	}()
}

func (sm *ServerManager) processServerSocketEvent(serverID string, evt *pbapi.ServerManagementAPIEvent) error {
	switch {
	case evt.GetConsole() != nil && evt.GetConsole().GetMessage() != "":
		isPublic := true
		if evt.GetConsole().Public != nil {
			isPublic = *evt.GetConsole().Public
		}

		msg := &ConsoleMessageModel{
			Message:  evt.GetConsole().GetMessage(),
			IsPublic: isPublic,
		}
		status := NewStatusConsole(msg)
		sm.PublishWS(APIManagementMessage{ServerID: serverID, Status: &status}, serverID)
	case evt.GetPlayers() != nil:
		playersEvt := evt.GetPlayers()
		if playersEvt == nil {
			// idk how this could even happen, but just in case
			return nil
		}

		logger.L().Debug("Received player list update", zap.String("server_id", serverID))

		players := playersEvt.GetPlayers()
		if players == nil {
			players = []*pbcommon.ServerPlayer{}
		}

		for i, p := range players {
			if p == nil {
				players = append(players[:i], players[i+1:]...)
				continue
			}

			if p.GetId() == "" || p.GetId() == "0" {
				players = append(players[:i], players[i+1:]...)
			}
		}

		sm.mu.Lock()
		if srv, exists := sm.ownedServers[serverID]; exists {
			srv.Players = players
		}
		sm.mu.Unlock()

		updateCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		existingTokens, err := sm.store.JoinTokens.GetByServerID(updateCtx, serverID)
		if err != nil {
			return fmt.Errorf("failed to get existing join tokens: %w", err)
		}

		if err := sm.store.Servers.UpdateByID(updateCtx, serverID, bson.M{
			"$set": bson.M{
				"player_count": len(players) + len(existingTokens),
				"last_updated": time.Now(),
			},
		}); err != nil {
			return fmt.Errorf("failed to update player count: %w", err)
		}

		pmPlayers := make([]ServerPlayerModel, 0)
		for _, p := range players {
			pmPlayers = append(pmPlayers, ServerPlayerModel{
				Name:   p.GetName(),
				ID:     p.GetId(),
				TeamID: p.GetTeamId(),
			})
		}

		status := NewStatusPlayerList(pmPlayers)
		sm.PublishWS(APIManagementMessage{ServerID: serverID, Status: &status}, serverID)
	}

	return nil
}

func (sm *ServerManager) HandleClientWS(w http.ResponseWriter, r *http.Request) {
	id := mux.Vars(r)["id"]
	if id == "" {
		http.Error(w, "Missing server ID", http.StatusBadRequest)
		return
	}

	token := r.Header.Get("Authorization")
	user, err := sm.store.Users.GetByToken(r.Context(), token)
	if err != nil {
		logger.L().Error("Failed to get user by token:", zap.Error(err))
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	if user == nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	server, err := sm.store.Servers.GetByID(r.Context(), id)
	if err != nil {
		logger.L().Error("Failed to get server by ID:", zap.Error(err))
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	if server == nil {
		http.Error(w, "Server not found", http.StatusGone)
		return
	}

	host, err := sm.store.Users.GetByToken(sm.ctx, server.HostToken)
	if err != nil {
		logger.L().Error("Failed to get host by token:", zap.Error(err))
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	isModerator := server.CanManage(host, user)
	isInServer := false
	sm.mu.RLock()
	if srv, exists := sm.playerCache[id]; exists {
		for _, p := range srv {
			if p.Id == user.ID {
				isInServer = true
				break
			}
		}
	}
	sm.mu.RUnlock()

	if !server.CanManage(host, user) && !isInServer {
		http.Error(w, "Forbidden", http.StatusForbidden)
		return
	}

	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		logger.L().Error("Upgrade error:", zap.Error(err))
		return
	}

	conn.SetReadLimit(1024 * 1024)
	_ = conn.SetReadDeadline(time.Now().Add(keepAliveTimeout))

	connID := util.GenerateToken()
	sm.mu.Lock()
	if sm.ownedClients[id] == nil {
		sm.ownedClients[id] = make(map[string]*OwnedClient)
	}
	sm.ownedClients[id][connID] = &OwnedClient{Conn: conn, ConnectionID: connID, IsModerator: isModerator}
	sm.mu.Unlock()

	sm.RequestPlayers(id)

	go func() {
		ticker := time.NewTicker(200 * time.Millisecond)
		defer ticker.Stop()
		defer conn.Close()

		for {
			_, _, err := conn.ReadMessage()
			if err != nil {
				break
			}

			err = conn.SetReadDeadline(time.Now().Add(keepAliveTimeout))
			if err != nil {
				logger.L().Error("Failed to set read deadline:", zap.Error(err))
				return
			}

			<-ticker.C
		}

		sm.mu.Lock()
		delete(sm.ownedClients[id], connID)
		sm.mu.Unlock()
	}()
}
