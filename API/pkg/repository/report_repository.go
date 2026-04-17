package repository

import (
	"context"
	"errors"
	"time"

	"github.com/ArmchairDevelopers/Kyber/API/api/v1/pbapi"
	"github.com/ArmchairDevelopers/Kyber/API/api/v1/pbcommon"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/models"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
)

type ReportRepository interface {
	Create(ctx context.Context, punishment *models.ReportModel) error
	GetAll(ctx context.Context) ([]*models.ReportModel, error)
	GetByID(ctx context.Context, id string) (*models.ReportModel, error)
	GetNewReportsByUserID(ctx context.Context, userID string) ([]*models.ReportModel, error)
	Update(ctx context.Context, id string, doc bson.M) error
	UpdateByFilter(ctx context.Context, filter bson.M, doc bson.M) error
	ListReportsGrouped(ctx context.Context) ([]*pbapi.PlayerReportSummary, error)
	GetReportsForUser(ctx context.Context, playerID string, active bool) ([]*pbapi.Report, error)
	GetOpenReportsForUser(ctx context.Context, userID string) ([]*models.ReportModel, error)
}

type mongoReportRepo struct {
	col mongo.Collection
}

func NewReportRepo(col *mongo.Collection) ReportRepository {
	return &mongoReportRepo{col: *col}
}

func (r *mongoReportRepo) UpdateByFilter(ctx context.Context, filter bson.M, doc bson.M) error {
	_, err := r.col.UpdateMany(ctx, filter, bson.D{
		{"$set", doc},
	})
	if err != nil {
		return err
	}

	return nil
}

func (r *mongoReportRepo) Update(ctx context.Context, id string, doc bson.M) error {
	_, err := r.col.UpdateOne(ctx, map[string]interface{}{
		"_id": id,
	}, bson.D{
		{"$set", doc},
	})
	if err != nil {
		return err
	}

	return nil
}

func (r *mongoReportRepo) GetByID(ctx context.Context, id string) (*models.ReportModel, error) {
	var report models.ReportModel
	err := r.col.FindOne(ctx, map[string]interface{}{
		"_id": id,
	}).Decode(&report)
	if err != nil {
		if errors.Is(err, mongo.ErrNoDocuments) {
			return nil, nil
		}
		return nil, err
	}

	return &report, nil
}

func (r *mongoReportRepo) GetAll(ctx context.Context) ([]*models.ReportModel, error) {
	cursor, err := r.col.Find(ctx, map[string]interface{}{})
	if err != nil {
		return nil, err
	}
	defer cursor.Close(ctx)

	var reports []*models.ReportModel
	for cursor.Next(ctx) {
		var report models.ReportModel
		if err := cursor.Decode(&report); err != nil {
			return nil, err
		}
		reports = append(reports, &report)
	}

	if err := cursor.Err(); err != nil {
		return nil, err
	}

	return reports, nil
}

func (r *mongoReportRepo) GetOpenReportsForUser(ctx context.Context, userID string) ([]*models.ReportModel, error) {
	cursor, err := r.col.Find(ctx, map[string]interface{}{
		"reported_player_id": userID,
		"status":             models.ReportStatusNew,
	})
	if err != nil {
		return nil, err
	}
	defer cursor.Close(ctx)

	var reports []*models.ReportModel
	for cursor.Next(ctx) {
		var report models.ReportModel
		if err := cursor.Decode(&report); err != nil {
			return nil, err
		}
		reports = append(reports, &report)
	}

	if err := cursor.Err(); err != nil {
		return nil, err
	}

	return reports, nil
}

func (r *mongoReportRepo) GetNewReportsByUserID(ctx context.Context, userID string) ([]*models.ReportModel, error) {
	cursor, err := r.col.Find(ctx, map[string]interface{}{
		"reporter_id": userID,
		"status":      models.ReportStatusNew,
	})
	if err != nil {
		return nil, err
	}
	defer cursor.Close(ctx)

	var reports []*models.ReportModel
	for cursor.Next(ctx) {
		var report models.ReportModel
		if err := cursor.Decode(&report); err != nil {
			return nil, err
		}
		reports = append(reports, &report)
	}

	if err := cursor.Err(); err != nil {
		return nil, err
	}

	return reports, nil
}

func (r *mongoReportRepo) Create(ctx context.Context, report *models.ReportModel) error {
	_, err := r.col.InsertOne(ctx, report)
	if err != nil {
		return err
	}

	return nil
}

type reportAgg struct {
	ID                 string               `bson:"id"`
	Reason             string               `bson:"reason"`
	Description        string               `bson:"description"`
	EvidenceLinks      []string             `bson:"evidence_links"`
	Status             string               `bson:"status"`
	CreatedAt          time.Time            `bson:"created_at"`
	UpdatedAt          time.Time            `bson:"updated_at"`
	ReporterID         string               `bson:"reporter_id"`
	ReporterName       string               `bson:"reporter_name"`
	ReportedPlayerID   string               `bson:"reported_player_id"`
	ReportedPlayerName string               `bson:"reported_player_name"`
	Notes              []string             `bson:"notes"`
	Punishment         *reportPunishmentAgg `bson:"punishment"`
	S3EvidenceIDs      []string             `bson:"s3_evidence_ids"`
}

type reportPunishmentAgg struct {
	ID            string    `bson:"id"`
	Type          string    `bson:"type"`
	Issuer        *string   `bson:"issuer"`
	User          string    `bson:"user"`
	Reason        string    `bson:"reason"`
	IssuedAt      time.Time `bson:"issued_at"`
	ExpiresAt     *int64    `bson:"expires_at"`
	ModeratorID   *string   `bson:"moderator_id"`
	ModeratorName *string   `bson:"moderator_name"`
}

func (r *mongoReportRepo) GetReportsForUser(ctx context.Context, playerID string, active bool) ([]*pbapi.Report, error) {
	status := bson.A{models.ReportStatusNew}
	if !active {
		status = bson.A{models.ReportStatusResolved, models.ReportStatusRejected}
	}

	pipeline := mongo.Pipeline{
		{{"$match", bson.D{
			{"reported_player_id", playerID},
			{"status", bson.D{{"$in", status}}},
		}}},
		{{"$lookup", bson.D{
			{"from", "punishments"},
			{"localField", "punishment_id"},
			{"foreignField", "_id"},
			{"as", "punishment"},
		}}},
		{{"$unwind", bson.D{
			{"path", "$punishment"},
			{"preserveNullAndEmptyArrays", true},
		}}},
		{{"$lookup", bson.D{
			{"from", "users"},
			{"localField", "punishment.moderator_id"},
			{"foreignField", "_id"},
			{"as", "moderator"},
		}}},
		{{"$unwind", bson.D{
			{"path", "$moderator"},
			{"preserveNullAndEmptyArrays", true},
		}}},
		{{"$lookup", bson.D{
			{"from", "users"},
			{"localField", "reporter_id"},
			{"foreignField", "_id"},
			{"as", "reporter"},
		}}},
		{{"$unwind", bson.D{
			{"path", "$reporter"},
			{"preserveNullAndEmptyArrays", true},
		}}},
		{{"$lookup", bson.D{
			{"from", "users"},
			{"localField", "reported_player_id"},
			{"foreignField", "_id"},
			{"as", "reportedPlayer"},
		}}},
		{{"$unwind", bson.D{
			{"path", "$reportedPlayer"},
			{"preserveNullAndEmptyArrays", true},
		}}},
		{{"$project", bson.D{
			{"id", "$_id"},
			{"reporter_id", "$reporter_id"},
			{"reporter_name", "$reporter.name"},
			{"reported_player_id", "$reported_player_id"},
			{"reported_player_name", "$reportedPlayer.name"},
			{"reason", 1},
			{"description", 1},
			{"evidence_links", 1},
			{"status", 1},
			{"created_at", 1},
			{"updated_at", 1},
			{"s3_evidence_ids", 1},
			{"notes", bson.D{{"$map", bson.D{
				{"input", "$notes"},
				{"as", "n"},
				{"in", "$$n.note"},
			}}}},
			{"punishment", bson.D{{"$cond", bson.D{
				{"if", bson.D{{"$ne", bson.A{"$punishment", nil}}}},
				{"then", bson.D{
					{"id", "$punishment._id"},
					{"type", "$punishment.type"},
					{"issuer", "$punishment.issuer"},
					{"user", "$punishment.user"},
					{"reason", "$punishment.reason"},
					{"issued_at", bson.D{{"$toLong", "$punishment.issued_at"}}},
					{"expires_at", bson.D{{"$toLong", "$punishment.expires_at"}}},
					{"moderator_id", "$punishment.moderator_id"},
					{"moderator_name", "$moderator.name"},
				}},
				{"else", nil},
			}}}}},
		}},
	}

	cursor, err := r.col.Aggregate(ctx, pipeline)
	if err != nil {
		return nil, err
	}
	defer cursor.Close(ctx)

	var out []*pbapi.Report
	for cursor.Next(ctx) {
		var report reportAgg
		if err := cursor.Decode(&report); err != nil {
			return nil, err
		}

		var punishment *pbapi.Punishment
		if report.Punishment != nil {
			var expiresAt uint64
			if report.Punishment.ExpiresAt != nil {
				expiresAt = uint64(*report.Punishment.ExpiresAt)
			}

			punishment = &pbapi.Punishment{
				Id:       report.Punishment.ID,
				Reason:   report.Punishment.Reason,
				Type:     pbapi.PunishmentType(pbapi.PunishmentType_value[report.Punishment.Type]),
				IssuedAt: uint64(report.Punishment.IssuedAt.Unix()),
				User: &pbcommon.KyberPlayer{
					Id:   report.Punishment.User,
					Name: report.ReportedPlayerName,
				},
				Issuer:     report.Punishment.Issuer,
				IssuerName: report.Punishment.ModeratorName,
				ExpiresAt:  &expiresAt,
			}
		}

		out = append(out, &pbapi.Report{
			Id:                 report.ID,
			Reason:             pbapi.ReportReason(pbapi.ReportReason_value[report.Reason]),
			Status:             pbapi.ReportStatus(pbapi.ReportStatus_value[report.Status]),
			Description:        report.Description,
			EvidenceLinks:      report.EvidenceLinks,
			ReporterId:         report.ReporterID,
			ReporterName:       report.ReporterName,
			ReportedPlayerId:   report.ReportedPlayerID,
			ReportedPlayerName: report.ReportedPlayerName,
			Notes:              report.Notes,
			CreatedAt:          report.CreatedAt.Unix(),
			UpdatedAt:          report.UpdatedAt.Unix(),
			Punishment:         punishment,
			S3EvidenceIds:      report.S3EvidenceIDs,
		})
	}

	if err := cursor.Err(); err != nil {
		return nil, err
	}

	return out, nil
}

type playerReportAgg struct {
	TargetUserID     string         `bson:"target_user_id"`
	TargetUsername   string         `bson:"target_username"`
	TotalReports     int            `bson:"total_reports"`
	LatestReportTime time.Time      `bson:"latest_report_time"`
	MostRecentStatus string         `bson:"most_recent_status"`
	MostRecentReason string         `bson:"most_recent_reason"`
	ReportsByReason  map[string]int `bson:"reports_by_reason"`
}

func (r *mongoReportRepo) ListReportsGrouped(ctx context.Context) ([]*pbapi.PlayerReportSummary, error) {
	pipeline := mongo.Pipeline{
		{{Key: "$sort", Value: bson.D{
			{Key: "reported_player_id", Value: 1},
			{Key: "status", Value: 1},
			{Key: "updated_at", Value: -1},
		}}},
		{{Key: "$group", Value: bson.M{
			"_id": bson.M{
				"player": "$reported_player_id",
				"status": "$status",
			},
			"total_reports":      bson.M{"$sum": 1},
			"latest_report_time": bson.M{"$max": "$created_at"},
			"reporter_ids":       bson.M{"$addToSet": "$reporter_id"},
			"reasons":            bson.M{"$push": "$reason"},
		}}},
		{{Key: "$lookup", Value: bson.M{
			"from": "users",
			"let":  bson.M{"playerId": "$_id.player"},
			"pipeline": mongo.Pipeline{
				{{Key: "$match", Value: bson.M{
					"$expr": bson.M{"$eq": bson.A{"$_id", "$$playerId"}},
				}}},
				{{Key: "$project", Value: bson.M{
					"_id":  1,
					"name": 1,
				}}},
			},
			"as": "userInfo",
		}}},
		{{Key: "$unwind", Value: bson.M{
			"path":                       "$userInfo",
			"preserveNullAndEmptyArrays": true,
		}}},
		{{Key: "$project", Value: bson.M{
			"_id":                0,
			"player_id":          "$_id.player",
			"status":             "$_id.status",
			"target_user_id":     "$_id.player",
			"target_username":    "$userInfo.name",
			"total_reports":      1,
			"latest_report_time": 1,
			"most_recent_status": "$_id.status",
			"reporter_ids":       1,
			"reports_by_reason": bson.M{
				"$arrayToObject": bson.M{
					"$map": bson.M{
						"input": bson.M{"$setUnion": bson.A{"$reasons", bson.A{}}},
						"as":    "reason",
						"in": bson.M{
							"k": "$$reason",
							"v": bson.M{
								"$size": bson.M{
									"$filter": bson.M{
										"input": "$reasons",
										"as":    "r",
										"cond":  bson.M{"$eq": bson.A{"$$r", "$$reason"}},
									},
								},
							},
						},
					},
				},
			},
		}}},
		{{Key: "$sort", Value: bson.D{
			{Key: "total_reports", Value: -1},
			{Key: "latest_report_time", Value: -1},
		}}},
	}

	cursor, err := r.col.Aggregate(ctx, pipeline)
	if err != nil {
		return nil, err
	}

	defer cursor.Close(ctx)

	var out []*pbapi.PlayerReportSummary
	for cursor.Next(ctx) {
		var agg playerReportAgg
		if err := cursor.Decode(&agg); err != nil {
			return nil, err
		}

		status := pbapi.ReportStatus(pbapi.ReportStatus_value[agg.MostRecentStatus])
		stateEnum := pbapi.ReportState_OPEN
		if status != pbapi.ReportStatus_NEW {
			stateEnum = pbapi.ReportState_CLOSED
		}

		summary := &pbapi.PlayerReportSummary{
			TargetUserId:     agg.TargetUserID,
			TargetUsername:   agg.TargetUsername,
			TotalReports:     int32(agg.TotalReports),
			ReportsByReason:  make(map[int32]int32, len(agg.ReportsByReason)),
			MostRecentStatus: status,
			LatestReportTime: agg.LatestReportTime.Unix(),
			State:            stateEnum,
		}

		for reasonStr, count := range agg.ReportsByReason {
			summary.ReportsByReason[pbapi.ReportReason_value[reasonStr]] = int32(count)
		}

		out = append(out, summary)
	}

	if err := cursor.Err(); err != nil {
		return nil, err
	}

	return out, nil
}
