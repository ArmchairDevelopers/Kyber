package rpc

import (
	"context"
	"time"

	"github.com/getsentry/sentry-go"
	middleware "github.com/grpc-ecosystem/go-grpc-middleware/v2"
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

func recoverWithSentry(hub *sentry.Hub, ctx context.Context, o SentryOptions) {
	if err := recover(); err != nil {
		eventID := hub.RecoverWithContext(ctx, err)
		if eventID != nil && o.WaitForDelivery {
			hub.Flush(o.Timeout)
		}
		if o.Repanic {
			panic(err)
		}
	}
}

func SentryUnaryServerInterceptor(opts SentryOptions) grpc.UnaryServerInterceptor {
	return func(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (interface{}, error) {
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

		ctx = tx.Context()
		defer tx.Finish()
		defer recoverWithSentry(hub, ctx, opts)

		resp, err := handler(ctx, req)
		if err != nil {
			hub.CaptureException(err)
			tx.Sampled = sentry.SampledTrue
		}
		tx.Status = toSpanStatus(status.Code(err))
		return resp, err
	}
}

func SentryStreamServerInterceptor(opts SentryOptions) grpc.StreamServerInterceptor {
	return func(srv interface{}, ss grpc.ServerStream, info *grpc.StreamServerInfo, handler grpc.StreamHandler) error {
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
		ctx = tx.Context()
		defer tx.Finish()

		wrapped := middleware.WrapServerStream(ss)
		wrapped.WrappedContext = ctx

		defer recoverWithSentry(hub, ctx, opts)

		err := handler(srv, wrapped)
		if err != nil {
			hub.CaptureException(err)
			tx.Sampled = sentry.SampledTrue
		}
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
	switch code {
	case codes.OK:
		return sentry.SpanStatusOK
	case codes.Canceled:
		return sentry.SpanStatusCanceled
	case codes.Unknown:
		return sentry.SpanStatusUnknown
	case codes.InvalidArgument:
		return sentry.SpanStatusInvalidArgument
	case codes.DeadlineExceeded:
		return sentry.SpanStatusDeadlineExceeded
	case codes.NotFound:
		return sentry.SpanStatusNotFound
	case codes.AlreadyExists:
		return sentry.SpanStatusAlreadyExists
	case codes.PermissionDenied:
		return sentry.SpanStatusPermissionDenied
	case codes.ResourceExhausted:
		return sentry.SpanStatusResourceExhausted
	case codes.FailedPrecondition:
		return sentry.SpanStatusFailedPrecondition
	case codes.Aborted:
		return sentry.SpanStatusAborted
	case codes.OutOfRange:
		return sentry.SpanStatusOutOfRange
	case codes.Unimplemented:
		return sentry.SpanStatusUnimplemented
	case codes.Internal:
		return sentry.SpanStatusInternalError
	case codes.Unavailable:
		return sentry.SpanStatusUnavailable
	case codes.DataLoss:
		return sentry.SpanStatusDataLoss
	case codes.Unauthenticated:
		return sentry.SpanStatusUnauthenticated
	default:
		return sentry.SpanStatusUndefined
	}
}

func DefaultSentryOptions() SentryOptions {
	return defaultSentryOptions()
}
