package mq

import (
	"encoding/json"

	"github.com/ArmchairDevelopers/Kyber/API/api/v1/pbapi"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/logger"
	amqp "github.com/rabbitmq/amqp091-go"
	"go.uber.org/zap"
	"google.golang.org/protobuf/encoding/protojson"
)

type PartyEventWire struct {
	PartyID uint64          `json:"party_id"`
	UserIDs []string        `json:"user_ids"`
	Event   json.RawMessage `json:"event"`
}

type PartyEventPublisher struct {
	ch *amqp.Channel
}

func NewPartyEventPublisher(ch *amqp.Channel) *PartyEventPublisher {
	return &PartyEventPublisher{ch: ch}
}

func (p *PartyEventPublisher) Publish(partyID uint64, userIDs []string, event *pbapi.PartyEvent) {
	eventBytes, err := protojson.Marshal(event)
	if err != nil {
		logger.L().Error("Failed to marshal party event proto", zap.Error(err))
		return
	}

	wire := PartyEventWire{
		PartyID: partyID,
		UserIDs: userIDs,
		Event:   json.RawMessage(eventBytes),
	}

	data, err := json.Marshal(wire)
	if err != nil {
		logger.L().Error("Failed to marshal party event", zap.Error(err))
		return
	}

	err = p.ch.Publish(
		"party_events",
		"",
		false,
		false,
		amqp.Publishing{
			ContentType: "application/json",
			Body:        data,
		},
	)

	if err != nil {
		logger.L().Error("Failed to publish party event", zap.Error(err))
	}
}
