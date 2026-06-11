package mq

import (
	"encoding/json"

	"github.com/ArmchairDevelopers/Kyber/API/api/v1/pbapi"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/logger"
	amqp "github.com/rabbitmq/amqp091-go"
	"go.uber.org/zap"
	"google.golang.org/protobuf/encoding/protojson"
)

type SessionEventWire struct {
	UserIDs []string        `json:"user_ids"`
	Event   json.RawMessage `json:"event"`
}

type PartyEventPublisher struct {
	client *Client
}

func NewPartyEventPublisher(client *Client) *PartyEventPublisher {
	return &PartyEventPublisher{client: client}
}

func (p *PartyEventPublisher) Publish(userIDs []string, event *pbapi.PartyEvent) {
	publishSessionEvent(p.client, userIDs, &pbapi.SessionEvent{
		Body: &pbapi.SessionEvent_PartyEvent{PartyEvent: event},
	})
}

type QueueEventPublisher struct {
	client *Client
}

func NewQueueEventPublisher(client *Client) *QueueEventPublisher {
	return &QueueEventPublisher{client: client}
}

func (p *QueueEventPublisher) Publish(userIDs []string, event *pbapi.QueueEvent) {
	publishSessionEvent(p.client, userIDs, &pbapi.SessionEvent{
		Body: &pbapi.SessionEvent_QueueEvent{QueueEvent: event},
	})
}

func publishSessionEvent(c *Client, userIDs []string, event *pbapi.SessionEvent) {
	if len(userIDs) == 0 {
		return
	}

	eventBytes, err := protojson.Marshal(event)
	if err != nil {
		logger.L().Error("Failed to marshal session event proto", zap.Error(err))
		return
	}

	data, err := json.Marshal(SessionEventWire{
		UserIDs: userIDs,
		Event:   eventBytes,
	})
	if err != nil {
		logger.L().Error("Failed to marshal session event wire", zap.Error(err))
		return
	}

	err = c.Publish("session_events", "", amqp.Publishing{
		ContentType: "application/json",
		Body:        data,
	})

	if err != nil {
		logger.L().Error("Failed to publish session event", zap.Error(err))
	}
}
