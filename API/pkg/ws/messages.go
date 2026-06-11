package ws

import (
	"encoding/json"
	"fmt"
)

type ServerPlayerModel struct {
	ID     string `json:"id"`
	Name   string `json:"name"`
	TeamID uint32 `json:"team_id"`
}

type ConsoleMessageModel struct {
	Message  string `json:"message"`
	IsPublic bool   `json:"is_public"`
}

type ServerPlayerSearchResponse struct {
	ServerID string `json:"server_id"`
	PlayerID string `json:"player_id"`
}

type ServerStatusMessage struct {
	Players        *[]ServerPlayerModel
	ConsoleMessage *ConsoleMessageModel
	PlayerSearch   *ServerPlayerSearchResponse
	Stale          bool

	tag statusTag
}

type statusTag int

const (
	statusPlayerList statusTag = iota
	statusConsoleMessage
	statusSearchServerID
	statusStaleServers
)

func NewStatusStaleServer() ServerStatusMessage {
	return ServerStatusMessage{Stale: true, tag: statusStaleServers}
}

func NewStatusPlayerList(players []ServerPlayerModel) ServerStatusMessage {
	return ServerStatusMessage{Players: &players, tag: statusPlayerList}
}

func NewStatusConsole(msg *ConsoleMessageModel) ServerStatusMessage {
	return ServerStatusMessage{ConsoleMessage: msg, tag: statusConsoleMessage}
}

func NewStatusSearchServerID(serverID string, playerID string) ServerStatusMessage {
	return ServerStatusMessage{PlayerSearch: &ServerPlayerSearchResponse{ServerID: serverID, PlayerID: playerID}, tag: statusSearchServerID}
}

func (m ServerStatusMessage) MarshalJSON() ([]byte, error) {
	switch m.tag {
	case statusStaleServers:
		return json.Marshal(map[string]bool{
			"STALE": m.Stale,
		})
	case statusPlayerList:
		return json.Marshal(map[string][]ServerPlayerModel{
			"PLAYER_LIST": *m.Players,
		})
	case statusConsoleMessage:
		return json.Marshal(map[string]ConsoleMessageModel{
			"CONSOLE_MESSAGE": *m.ConsoleMessage,
		})
	case statusSearchServerID:
		return json.Marshal(map[string]ServerPlayerSearchResponse{
			"SEARCH_SERVER": *m.PlayerSearch,
		})
	default:
		return nil, fmt.Errorf("ServerStatusMessage: unknown variant")
	}
}

func (m *ServerStatusMessage) UnmarshalJSON(data []byte) error {
	var raw map[string]json.RawMessage
	if err := json.Unmarshal(data, &raw); err != nil {
		return err
	}

	m.Stale = false
	if _, ok := raw["STALE"]; ok {
		m.Stale = true
		m.tag = statusStaleServers
		return nil
	}
	if v, ok := raw["PLAYER_LIST"]; ok {
		if err := json.Unmarshal(v, &m.Players); err != nil {
			return err
		}
		m.tag = statusPlayerList
		return nil
	}
	if v, ok := raw["CONSOLE_MESSAGE"]; ok {
		var s ConsoleMessageModel
		if err := json.Unmarshal(v, &s); err != nil {
			return err
		}
		m.ConsoleMessage = &s
		m.tag = statusConsoleMessage
		return nil
	}
	if v, ok := raw["SEARCH_SERVER"]; ok {
		var s ServerPlayerSearchResponse
		if err := json.Unmarshal(v, &s); err != nil {
			return err
		}
		m.PlayerSearch = &s
	}
	return fmt.Errorf("ServerStatusMessage: no matching key in %s", string(data))
}

type ServerRequestMessage struct {
	RunCommand   string
	KickPlayer   *struct{ UserID, Reason string }
	PlayerList   bool
	SearchPlayer string

	tag requestTag
}

type requestTag int

const (
	reqRunCommand requestTag = iota
	reqKickPlayer
	reqPlayerList
	reqSearchPlayer
)

func NewReqRunCommand(cmd string) ServerRequestMessage {
	return ServerRequestMessage{RunCommand: cmd, tag: reqRunCommand}
}

func NewReqKickPlayer(userID, reason string) ServerRequestMessage {
	return ServerRequestMessage{KickPlayer: &struct{ UserID, Reason string }{userID, reason}, tag: reqKickPlayer}
}

func NewReqSearchPlayer(id string) ServerRequestMessage {
	return ServerRequestMessage{SearchPlayer: id, tag: reqRunCommand}
}

func NewReqPlayerList() ServerRequestMessage {
	return ServerRequestMessage{PlayerList: true, tag: reqPlayerList}
}

func (m ServerRequestMessage) MarshalJSON() ([]byte, error) {
	switch m.tag {
	case reqRunCommand:
		return json.Marshal(map[string]string{
			"RUN_COMMAND": m.RunCommand,
		})
	case reqKickPlayer:
		return json.Marshal(map[string][]string{
			"KICK_PLAYER": {m.KickPlayer.UserID, m.KickPlayer.Reason},
		})
	case reqPlayerList:
		return json.Marshal(map[string][]interface{}{
			"PLAYER_LIST": {},
		})
	case reqSearchPlayer:
		return json.Marshal(map[string]string{
			"SEARCH_PLAYER": m.SearchPlayer,
		})
	default:
		return nil, fmt.Errorf("ServerRequestMessage: unknown variant")
	}
}

func (m *ServerRequestMessage) UnmarshalJSON(data []byte) error {
	var raw map[string]json.RawMessage
	if err := json.Unmarshal(data, &raw); err != nil {
		return err
	}
	if v, ok := raw["RUN_COMMAND"]; ok {
		if err := json.Unmarshal(v, &m.RunCommand); err != nil {
			return err
		}
		m.tag = reqRunCommand
		return nil
	}
	if v, ok := raw["KICK_PLAYER"]; ok {
		var arr []string
		if err := json.Unmarshal(v, &arr); err != nil {
			return err
		}
		m.KickPlayer = &struct{ UserID, Reason string }{arr[0], arr[1]}
		m.tag = reqKickPlayer
		return nil
	}
	if _, ok := raw["PLAYER_LIST"]; ok {
		m.PlayerList = true
		m.tag = reqPlayerList
		return nil
	}
	if v, ok := raw["SEARCH_PLAYER"]; ok {
		if err := json.Unmarshal(v, &m.SearchPlayer); err != nil {
			return err
		}
		m.tag = reqSearchPlayer
	}
	return fmt.Errorf("ServerRequestMessage: no matching key in %s", string(data))
}

type APIManagementMessage struct {
	ServerID string

	Status  *ServerStatusMessage
	Request *ServerRequestMessage
}

func (m APIManagementMessage) MarshalJSON() ([]byte, error) {
	if m.Status != nil {
		return json.Marshal(map[string]interface{}{
			"SERVER_STATUS": []interface{}{m.ServerID, m.Status},
		})
	}
	if m.Request != nil {
		return json.Marshal(map[string]interface{}{
			"SERVER_REQUEST": []interface{}{m.ServerID, m.Request},
		})
	}
	return nil, fmt.Errorf("APIManagementMessage: no variant set")
}

func (m *APIManagementMessage) UnmarshalJSON(data []byte) error {
	var raw map[string]json.RawMessage
	if err := json.Unmarshal(data, &raw); err != nil {
		return err
	}
	if v, ok := raw["SERVER_STATUS"]; ok {
		var arr []json.RawMessage
		if err := json.Unmarshal(v, &arr); err != nil {
			return err
		}
		m.ServerID = string(arr[0][1 : len(arr[0])-1])
		var s ServerStatusMessage
		if err := json.Unmarshal(arr[1], &s); err != nil {
			return err
		}
		m.Status = &s
		return nil
	}
	if v, ok := raw["SERVER_REQUEST"]; ok {
		var arr []json.RawMessage
		if err := json.Unmarshal(v, &arr); err != nil {
			return err
		}
		m.ServerID = string(arr[0][1 : len(arr[0])-1])
		var r ServerRequestMessage
		if err := json.Unmarshal(arr[1], &r); err != nil {
			return err
		}
		m.Request = &r
		return nil
	}
	return fmt.Errorf("APIManagementMessage: no key in %s", string(data))
}
