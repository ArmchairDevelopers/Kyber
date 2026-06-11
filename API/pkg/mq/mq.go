package mq

import (
	"fmt"
	"sync"
	"time"

	"github.com/ArmchairDevelopers/Kyber/API/pkg/logger"
	amqp "github.com/rabbitmq/amqp091-go"
	"go.uber.org/zap"
)

type ExchangeConfig struct {
	Name    string
	Kind    string
	Durable bool
}

type Client struct {
	url string

	mu        sync.Mutex
	conn      *amqp.Connection
	ch        *amqp.Channel
	exchanges []ExchangeConfig
}

func NewClient(amqpURL string, exchanges []ExchangeConfig) (*Client, error) {
	c := &Client{url: amqpURL, exchanges: exchanges}

	c.mu.Lock()
	defer c.mu.Unlock()

	if err := c.redial(); err != nil {
		return nil, err
	}

	return c, nil
}

func (c *Client) Publish(exchange, key string, msg amqp.Publishing) error {
	c.mu.Lock()
	ch := c.ch
	c.mu.Unlock()

	err := ch.Publish(exchange, key, false, false, msg)
	if err == nil {
		return nil
	}

	if reconnErr := c.reconnect(); reconnErr != nil {
		return err
	}

	c.mu.Lock()
	ch = c.ch
	c.mu.Unlock()

	return ch.Publish(exchange, key, false, false, msg)
}

func (c *Client) newChannel() (*amqp.Channel, error) {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.conn.IsClosed() {
		if err := c.redial(); err != nil {
			return nil, err
		}
	}

	return c.conn.Channel()
}

func (c *Client) ConsumeFanout(exchange string, handle func(body []byte)) {
	for {
		c.consumeFanout(exchange, handle)
		logger.L().Warn("event consumer disconnected", zap.String("exchange", exchange))
		time.Sleep(5 * time.Second)
	}
}

func (c *Client) consumeFanout(exchange string, handle func(body []byte)) {
	ch, err := c.newChannel()
	if err != nil {
		logger.L().Error("failed to open consumer channel", zap.Error(err), zap.String("exchange", exchange))
		return
	}

	defer ch.Close()

	q, err := ch.QueueDeclare("", false, true, true, false, nil)
	if err != nil {
		logger.L().Error("failed to declare consumer queue", zap.Error(err), zap.String("exchange", exchange))
		return
	}

	if err := ch.QueueBind(q.Name, "", exchange, false, nil); err != nil {
		logger.L().Error("failed to bind consumer queue", zap.Error(err), zap.String("exchange", exchange))
		return
	}

	msgs, err := ch.Consume(q.Name, "", true, false, false, false, nil)
	if err != nil {
		logger.L().Error("failed to consume events", zap.Error(err), zap.String("exchange", exchange))
		return
	}

	for msg := range msgs {
		handle(msg.Body)
	}
}

func (c *Client) reconnect() error {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.conn.IsClosed() {
		return c.redial()
	}

	if c.ch.IsClosed() {
		ch, err := c.conn.Channel()
		if err != nil {
			return fmt.Errorf("reopening channel: %w", err)
		}
		c.ch = ch
	}

	return nil
}

func (c *Client) redial() error {
	conn, err := amqp.Dial(c.url)
	if err != nil {
		return fmt.Errorf("dialing amqp: %w", err)
	}

	ch, err := conn.Channel()
	if err != nil {
		conn.Close()
		return fmt.Errorf("opening channel: %w", err)
	}

	c.conn = conn
	c.ch = ch

	for _, cfg := range c.exchanges {
		if err := ch.ExchangeDeclare(cfg.Name, cfg.Kind, cfg.Durable, false, false, false, nil); err != nil {
			return fmt.Errorf("declare exchange %q: %w", cfg.Name, err)
		}
	}

	return nil
}

func (c *Client) Close() error {
	c.ch.Close()
	return c.conn.Close()
}
