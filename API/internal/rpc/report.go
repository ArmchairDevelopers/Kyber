package rpc

import (
	"context"
	"fmt"
	"os"
	"time"

	"github.com/ArmchairDevelopers/Kyber/API/api/v1/pbapi"
	"github.com/ArmchairDevelopers/Kyber/API/api/v1/pbcommon"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/db"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/logger"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/models"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/mq"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/util"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/ws"
	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
	amqp "github.com/rabbitmq/amqp091-go"
	"go.mongodb.org/mongo-driver/bson"
	"go.uber.org/zap"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

var allowedExt = map[string]bool{
	"jpg":  true,
	"jpeg": true,
	"png":  true,
	"webp": true,
	"mp4":  true,
}

type ReportServiceServer struct {
	store      *db.Store
	sm         *ws.ServerManager
	minio      *minio.Client
	mqClient   *mq.Client
	bucketName string
	pbapi.UnimplementedReportServiceServer
}

func NewReportServer(store *db.Store, sm *ws.ServerManager, client *mq.Client) *ReportServiceServer {
	minioEndpoint := os.Getenv("R2_HOST")
	accessKey := os.Getenv("R2_ACCESS_KEY")
	secretKey := os.Getenv("R2_SECRET_KEY")

	if minioEndpoint == "" || accessKey == "" || secretKey == "" {
		panic("R2_HOST, R2_ACCESS_KEY, and R2_SECRET_KEY must be set")
	}

	minioClient, err := minio.New(minioEndpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(accessKey, secretKey, ""),
		Secure: true,
	})

	bucketName := os.Getenv("R2_BUCKET_NAME")
	if bucketName == "" {
		panic("R2_BUCKET_NAME must be set")
	}

	if err != nil {
		panic("Failed to create MinIO client: " + err.Error())
	}

	return &ReportServiceServer{
		store:      store,
		sm:         sm,
		mqClient:   client,
		minio:      minioClient,
		bucketName: bucketName,
	}
}

func (s *ReportServiceServer) GetUserInfo(ctx context.Context, req *pbapi.UserInfoRequest) (*pbapi.UserInfoResponse, error) {
	user := ctx.Value("user").(*models.UserModel)
	if !user.Entitled(models.EntitlementStaff) {
		return nil, status.Error(codes.PermissionDenied, "User is not a staff member")
	}

	target, err := s.store.Users.GetByID(ctx, req.GetUserId())
	if err != nil {
		logger.L().Error("Failed to get target user", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get target user")
	}

	if target == nil {
		return nil, status.Error(codes.NotFound, "Target user not found")
	}

	punishment, err := s.store.Punishments.GetGlobalBan(ctx, target.ID)
	if err != nil {
		logger.L().Error("Failed to get punishment", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get punishment")
	}

	deviceIds := make([]string, len(target.EAData.DeviceIDs))
	for i, device := range target.EAData.DeviceIDs {
		deviceIds[i] = device.ID
	}

	resp := &pbapi.UserInfoResponse{
		UserId:        target.ID,
		Username:      target.Name,
		Created:       target.Created.Unix(),
		LastSeen:      target.LastSeen.Unix(),
		LoginCount:    target.MetricData.LoginCount,
		ServersHosted: target.MetricData.ServersHosted,
		ServersJoined: target.MetricData.ServersJoined,
		PersonaId:     target.EAData.PersonaID,
		Nickname:      target.EAData.Nickname,
		CountryCode:   target.EAData.Country,
		Entitlements:  target.ConvEntitlements(),
		IsBanned:      punishment != nil,
		DeviceIds:     deviceIds,
	}

	if punishment != nil {
		var expires int64
		if punishment.ExpiresAt != nil {
			expires = punishment.ExpiresAt.Unix()
		} else {
			expires = 0
		}

		banReason := ""
		if punishment.Reason != nil {
			banReason = *punishment.Reason
		}

		resp.BanExpiresAt = &expires
		resp.BanReason = &banReason
	}

	return resp, nil
}

func (s *ReportServiceServer) GenerateEvidenceLinks(ctx context.Context, req *pbapi.GenerateEvidenceLinksRequest) (*pbapi.GenerateEvidenceLinksResponse, error) {
	links := make([]string, 0)
	for ext, count := range req.FileExtensions {
		if !allowedExt[ext] {
			logger.L().Warn("Invalid file extension", zap.String("extension", ext))
			return nil, status.Error(codes.InvalidArgument, "Invalid file extension: "+ext)
		}

		for i := 0; i < int(count); i++ {
			fileName := fmt.Sprintf("%s.%s", util.GenerateToken(), ext)
			presignedURL, err := s.minio.PresignedPutObject(ctx, s.bucketName, fileName, time.Minute*10)
			if err != nil {
				logger.L().Error("Failed to generate presigned URL", zap.Error(err))
				return nil, status.Error(codes.Internal, "Failed to generate presigned URL")
			}

			url := presignedURL.String()
			links = append(links, url)
		}
	}

	return &pbapi.GenerateEvidenceLinksResponse{Links: links}, nil
}

func (s *ReportServiceServer) SearchUser(ctx context.Context, req *pbapi.SearchUserRequest) (*pbapi.SearchUserResponse, error) {
	users, err := s.store.Users.SearchMulti(ctx, req.GetQuery())
	if err != nil {
		logger.L().Error("failed to search user", zap.Error(err))
		return nil, status.Error(codes.InvalidArgument, "Failed to search users")
	}

	cnvUsers := make([]*pbcommon.KyberPlayer, 0, len(users))
	for _, u := range users {
		cnvUsers = append(cnvUsers, &pbcommon.KyberPlayer{
			Id:   u.ID,
			Name: u.Name,
		})
	}

	return &pbapi.SearchUserResponse{Users: cnvUsers}, nil
}

func (s *ReportServiceServer) ApproveReports(ctx context.Context, req *pbapi.ApproveReportsRequest) (*pbcommon.Empty, error) {
	user := ctx.Value("user").(*models.UserModel)

	if !user.Entitled(models.EntitlementStaff) {
		return nil, status.Error(codes.PermissionDenied, "User is not a staff member")
	}

	target, err := s.store.Users.GetByID(ctx, req.GetPlayerId())
	if err != nil {
		logger.L().Error("Failed to get target user", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get target user")
	}

	if target == nil {
		return nil, status.Error(codes.NotFound, "Target user not found")
	}

	reports, err := s.store.Reports.GetOpenReportsForUser(ctx, target.ID)
	if err != nil {
		logger.L().Error("Failed to get new reports", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get new reports")
	}

	if len(reports) == 0 {
		return nil, status.Error(codes.NotFound, "No new reports found")
	}

	ids := make([]string, 0, len(reports))
	for _, report := range reports {
		if report.ID == "" {
			continue
		}

		ids = append(ids, report.ID)
	}

	var expires *time.Time
	if req.GetBanDuration() > 0 {
		exp := time.Now().Add(time.Duration(req.GetBanDuration()) * time.Second)
		expires = &exp
	} else {
		expires = nil
	}

	deviceIDs := make([]string, len(target.EAData.DeviceIDs))
	for i, device := range target.EAData.DeviceIDs {
		deviceIDs[i] = device.ID
	}

	var lastUsedIP string
	var lastUsed *time.Time
	for _, ip := range target.IPs {
		if lastUsed == nil || ip.LastSeen.After(*lastUsed) {
			lastUsed = &ip.LastSeen
			lastUsedIP = ip.IP
		}
	}

	punishment := &models.PunishmentModel{
		ID:          util.GenerateShortToken(),
		Issuer:      nil,
		ModeratorID: &user.ID,
		User:        &target.ID,
		Reason:      &req.BanMessage,
		ExpiresAt:   expires,
		LastUsedIP:  &lastUsedIP,
		DeviceIDs:   &deviceIDs,
		IssuedAt:    time.Now(),
		Type:        models.PunishmentTypeBan,
		ReportIDs:   &ids,
	}

	if err := s.store.Punishments.Create(ctx, punishment); err != nil {
		logger.L().Error("Failed to create punishment", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to create punishment")
	}

	err = s.store.Reports.UpdateByFilter(ctx, bson.M{"_id": bson.M{"$in": ids}, "status": models.ReportStatusNew}, bson.M{
		"status":       models.ReportStatusResolved,
		"updated_at":   time.Now(),
		"moderator_id": &user.ID,
	})

	if err != nil {
		logger.L().Error("Failed to update reports", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to update reports")
	}

	err = s.mqClient.Publish("reports", "", amqp.Publishing{
		Body:        []byte(ids[0]),
		ContentType: "text/plain",
	})
	if err != nil {
		logger.L().Error("Failed to publish report", zap.Error(err))
	}

	if err := s.sm.KickUserGlobally(ctx, target.ID); err != nil {
		logger.L().Error("Failed to kick user globally", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to kick user globally")
	}

	return &pbcommon.Empty{}, nil
}

func (s *ReportServiceServer) RejectReport(ctx context.Context, req *pbapi.RejectReportRequest) (*pbcommon.Empty, error) {
	user := ctx.Value("user").(*models.UserModel)

	if !user.Entitled(models.EntitlementStaff) {
		return nil, status.Error(codes.PermissionDenied, "User is not a staff member")
	}

	report, err := s.store.Reports.GetByID(ctx, req.GetReportId())
	if err != nil {
		logger.L().Error("Failed to get report", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get report")
	}

	if report == nil {
		return nil, status.Error(codes.NotFound, "Report not found")
	}

	if report.Status != models.ReportStatusNew {
		return nil, status.Error(codes.InvalidArgument, "Report has already been processed")
	}

	err = s.store.Reports.Update(ctx, report.ID, bson.M{"status": models.ReportStatusRejected, "updated_at": time.Now(), "moderator_id": &user.ID})
	if err != nil {
		logger.L().Error("Failed to update report status", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to update report status")
	}

	return &pbcommon.Empty{}, nil
}

func (s *ReportServiceServer) UpdateStatus(ctx context.Context, req *pbapi.UpdateStatusRequest) (*pbcommon.Empty, error) {
	user := ctx.Value("user").(*models.UserModel)

	if !user.Entitled(models.EntitlementStaff) {
		return nil, status.Error(codes.PermissionDenied, "User is not a staff member")
	}

	if req.GetId() == "" {
		return nil, status.Error(codes.InvalidArgument, "Report ID cannot be empty")
	}

	report, err := s.store.Reports.GetByID(ctx, req.GetId())
	if err != nil {
		logger.L().Error("Failed to get report", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get report")
	}

	if report == nil {
		return nil, status.Error(codes.NotFound, "Report not found")
	}

	if req.GetStatus() == pbapi.ReportStatus_NEW {
		return nil, status.Error(codes.InvalidArgument, "Cannot set report status to NEW")
	}

	if req.GetStatus() == pbapi.ReportStatus_RESOLVED || req.GetStatus() == pbapi.ReportStatus_REJECTED {
		err = s.store.Reports.UpdateByFilter(ctx, bson.M{"reported_player_id": report.ReportedPlayerID, "$or": []bson.M{
			{"status": models.ReportStatusNew},
		}}, bson.M{
			"status":       models.GetReportStatusFromProto(req.GetStatus()),
			"updated_at":   time.Now(),
			"moderator_id": &user.ID,
		})
		if err != nil {
			logger.L().Error("Failed to update reports by filter", zap.Error(err))
			return nil, status.Error(codes.Internal, "Failed to update reports by filter")
		}
	}

	if req.GetModNotes() != "" {
		note := models.ReportNote{
			CreatedAt: time.Now(),
			Note:      req.GetModNotes(),
			UserID:    user.ID,
		}

		report.Notes = append(report.Notes, note)
	}

	report.Status = models.GetReportStatusFromProto(req.GetStatus())
	report.UpdatedAt = time.Now()
	if err := s.store.Reports.Update(ctx, report.ID, bson.M{"status": report.Status, "updated_at": report.UpdatedAt, "notes": util.ToBson(&report.Notes)}); err != nil {
		logger.L().Error("Failed to update report", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to update report")
	}

	return &pbcommon.Empty{}, nil
}

func (s *ReportServiceServer) GetUserReports(ctx context.Context, req *pbapi.GetReportRequest) (*pbapi.GetReportResponse, error) {
	user := ctx.Value("user").(*models.UserModel)

	if !user.Entitled(models.EntitlementStaff) {
		return nil, status.Error(codes.PermissionDenied, "User is not a staff member")
	}

	active := false
	if req.GetState() == pbapi.ReportState_OPEN {
		active = true
	}

	reports, err := s.store.Reports.GetReportsForUser(ctx, req.GetPlayerId(), active)
	if err != nil {
		logger.L().Error("Failed to get report", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get reports")
	}

	if reports == nil {
		return nil, status.Error(codes.NotFound, "Reports not found")
	}

	pastPunishments, err := s.store.Punishments.GetForUser(ctx, req.GetPlayerId())
	if err != nil {
		logger.L().Error("Failed to get report", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get reports")
	}

	filteredPunishments := make([]*pbapi.Punishment, 0)
	for _, punishment := range pastPunishments {
		if punishment.Issuer != nil {
			continue
		}

		filteredPunishments = append(filteredPunishments, punishment.Proto())
	}

	return &pbapi.GetReportResponse{
		Reports:     reports,
		Punishments: filteredPunishments,
	}, nil
}

func (s *ReportServiceServer) CreateReport(ctx context.Context, req *pbapi.CreateReportRequest) (*pbcommon.Empty, error) {
	user := ctx.Value("user").(*models.UserModel)

	if req.Report == nil {
		return nil, status.Error(codes.InvalidArgument, "Report cannot be nil")
	}

	openReports, err := s.store.Reports.GetNewReportsByUserID(ctx, user.ID)
	if err != nil {
		logger.L().Error("Failed to get open reports", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get open reports")
	}

	if len(openReports) >= 6 {
		return nil, status.Error(codes.ResourceExhausted, "You have reached the maximum number of open reports")
	}

	openReportsForTarget := 0
	for _, report := range openReports {
		if report.ReportedPlayerID == req.Report.ReportedPlayerId {
			openReportsForTarget++
		}
	}

	if openReportsForTarget >= 2 {
		return nil, status.Error(codes.ResourceExhausted, "You have reached the maximum number of open reports for this player")
	}

	for _, link := range req.Report.EvidenceLinks {
		if !util.IsValidURL(link) {
			return nil, status.Error(codes.InvalidArgument, "Invalid evidence link: "+link)
		}
	}

	report := req.GetReport()
	reportedUser, err := s.store.Users.GetByID(ctx, report.ReportedPlayerId)
	if err != nil {
		logger.L().Error("Failed to get reported user", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get reported user")
	}

	if reportedUser == nil {
		return nil, status.Error(codes.NotFound, "Reported user not found")
	}

	reportModel := models.ReportModel{
		ID:               util.GenerateShortToken(),
		ReportedPlayerID: report.ReportedPlayerId,
		ReporterID:       user.ID,
		Description:      report.Description,
		EvidenceLinks:    report.EvidenceLinks,
		Reason:           models.GetReportReasonFromProto(report.Reason),
		Notes:            make([]models.ReportNote, 0),
		Status:           models.ReportStatusNew,
		CreatedAt:        time.Now(),
		UpdatedAt:        time.Now(),
		S3EvidenceIDs:    report.GetEvidenceIds(),
	}

	if err := s.store.Reports.Create(ctx, &reportModel); err != nil {
		logger.L().Error("Failed to create report", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to create report")
	}

	err = s.mqClient.Publish("reports", "", amqp.Publishing{
		Body:        []byte(reportModel.ID),
		ContentType: "text/plain",
	})

	if err != nil {
		logger.L().Error("Failed to publish image hash to queue", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to publish image hash")
	}

	return &pbcommon.Empty{}, nil
}

func (s *ReportServiceServer) ListReports(ctx context.Context, _ *pbcommon.Empty) (*pbapi.ListReportsResponse, error) {
	user := ctx.Value("user").(*models.UserModel)

	if !user.Entitled(models.EntitlementStaff) {
		return nil, status.Error(codes.PermissionDenied, "User is not a staff member")
	}

	reports, err := s.store.Reports.ListReportsGrouped(ctx)
	if err != nil {
		logger.L().Error("Failed to get reports", zap.Error(err))
		return nil, status.Error(codes.Internal, "Failed to get reports")
	}

	return &pbapi.ListReportsResponse{
		Reports: reports,
	}, nil
}
