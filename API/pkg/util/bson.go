package util

import (
	"fmt"

	"github.com/ArmchairDevelopers/Kyber/API/pkg/logger"
	"go.mongodb.org/mongo-driver/v2/bson"
)

func ToBson(v interface{}) bson.M {
	raw, err := bson.Marshal(v)
	if err != nil {
		logger.L().Error(err.Error())
		return nil
	}

	var m bson.M
	if err := bson.Unmarshal(raw, &m); err != nil {
		logger.L().Error(fmt.Sprintf("Failed to unmarshal bson: %v", err))
		return nil
	}

	return m
}
