package db

import (
	"context"
	"sync"
	"time"

	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
)

var (
	clientSingleton *mongo.Client
	once            sync.Once
)

func Connect(uri string) (*mongo.Client, error) {
	var err error
	once.Do(func() {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		clientOpts := options.Client().
			ApplyURI(uri).
			SetMaxPoolSize(20).
			SetMinPoolSize(0).
			SetMaxConnIdleTime(30 * time.Second).
			SetConnectTimeout(2 * time.Second).
			SetServerSelectionTimeout(3 * time.Second)

		clientSingleton, err = mongo.Connect(clientOpts)
		if err != nil {
			return
		}

		if err = clientSingleton.Ping(ctx, nil); err != nil {
			_ = clientSingleton.Disconnect(ctx)
		}
	})
	return clientSingleton, err
}

func GetCollection(dbName, collName string) *mongo.Collection {
	if clientSingleton == nil {
		panic("mongo client not initialized; call db.Connect first")
	}
	return clientSingleton.Database(dbName).Collection(collName)
}

func Close(ctx context.Context) error {
	if clientSingleton != nil {
		return clientSingleton.Disconnect(ctx)
	}
	return nil
}
