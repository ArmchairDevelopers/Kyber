package rpc

import (
	"context"
	"time"

	"github.com/ArmchairDevelopers/Kyber/API/pkg/logger"
	"github.com/ArmchairDevelopers/Kyber/API/pkg/models"
	"github.com/getsentry/sentry-go"
	middleware "github.com/grpc-ecosystem/go-grpc-middleware/v2"
	"go.uber.org/zap"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
)

type SentryOptions struct {
	Repanic         bool
	WaitForDelivery bool
	Timeout         time.Duration
}

func defaultSentryOptions() SentryOptions {
	return SentryOptions{
		Repanic:         false,
		WaitForDelivery: false,
		Timeout:         2 * time.Second,
	}
}

func recoverWithSentry(hub *sentry.Hub, ctx context.Context, o SentryOptions, err *error) {
	if r := recover(); r != nil {
		logger.Console().Error("panic in gRPC handler", zap.Any("panic", r), zap.Stack("stack"))

		eventID := hub.RecoverWithContext(ctx, r)
		if eventID != nil && o.WaitForDelivery {
			hub.Flush(o.Timeout)
		}
		if o.Repanic {
			panic(r)
		}
		*err = status.Error(codes.Internal, "internal server error")
	}
}

func setSentryUser(ctx context.Context, user *models.UserModel) {
	if hub := sentry.GetHubFromContext(ctx); hub != nil {
		hub.Scope().SetUser(sentry.User{ID: user.ID, Username: user.Name})
	}
}

func SentryUnaryServerInterceptor(opts SentryOptions) grpc.UnaryServerInterceptor {
	return func(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (resp interface{}, err error) {
		hub := sentry.GetHubFromContext(ctx)
		if hub == nil {
			hub = sentry.CurrentHub().Clone()
			ctx = sentry.SetHubOnContext(ctx, hub)
		}

		md, _ := metadata.FromIncomingContext(ctx)
		tx := sentry.StartTransaction(
			ctx,
			info.FullMethod,
			sentry.WithOpName("grpc.server"),
			sentry.WithDescription(info.FullMethod),
			sentry.WithTransactionSource(sentry.SourceURL),
			continueFromGrpcMetadata(md),
		)
		tx.SetData("grpc.request.method", info.FullMethod)

		hub.Scope().SetTag("grpc.method", info.FullMethod)
		defer logger.BindScope(hub.Scope())()

		ctx = tx.Context()
		defer tx.Finish()
		defer recoverWithSentry(hub, ctx, opts, &err)

		resp, err = handler(ctx, req)
		tx.Status = toSpanStatus(status.Code(err))
		return resp, err
	}
}

func SentryStreamServerInterceptor(opts SentryOptions) grpc.StreamServerInterceptor {
	return func(srv interface{}, ss grpc.ServerStream, info *grpc.StreamServerInfo, handler grpc.StreamHandler) (err error) {
		ctx := ss.Context()
		hub := sentry.GetHubFromContext(ctx)
		if hub == nil {
			hub = sentry.CurrentHub().Clone()
			ctx = sentry.SetHubOnContext(ctx, hub)
		}

		md, _ := metadata.FromIncomingContext(ctx)
		tx := sentry.StartTransaction(
			ctx,
			info.FullMethod,
			sentry.WithOpName("grpc.server"),
			sentry.WithDescription(info.FullMethod),
			sentry.WithTransactionSource(sentry.SourceURL),
			continueFromGrpcMetadata(md),
		)
		tx.SetData("grpc.request.method", info.FullMethod)

		hub.Scope().SetTag("grpc.method", info.FullMethod)
		defer logger.BindScope(hub.Scope())()

		ctx = tx.Context()
		defer tx.Finish()

		wrapped := middleware.WrapServerStream(ss)
		wrapped.WrappedContext = ctx

		defer recoverWithSentry(hub, ctx, opts, &err)

		err = handler(srv, wrapped)
		tx.Status = toSpanStatus(status.Code(err))
		return err
	}
}

func continueFromGrpcMetadata(md metadata.MD) sentry.SpanOption {
	if md == nil {
		return func(*sentry.Span) {}
	}
	var trace, baggage string
	if v, ok := md[sentry.SentryTraceHeader]; ok && len(v) > 0 {
		trace = v[0]
	}
	if v, ok := md[sentry.SentryBaggageHeader]; ok && len(v) > 0 {
		baggage = v[0]
	}
	return sentry.ContinueFromHeaders(trace, baggage)
}

func toSpanStatus(code codes.Code) sentry.SpanStatus {
    // apparently sentry's span statuses are identical to grpc's codes just shifted by 1?
	return sentry.SpanStatus(code + 1)
}

func DefaultSentryOptions() SentryOptions {
	return defaultSentryOptions()
}
