package logger

import (
	"os"
	"sync"
	"time"

	"github.com/TheZeroSlave/zapsentry"
	"github.com/getsentry/sentry-go"
	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

var (
	once    sync.Once
	zl      *zap.Logger
	console *zap.Logger
)

func Init(s *sentry.Client) error {
	var err error
	once.Do(func() {
		encCfg := zapcore.EncoderConfig{
			TimeKey:          "T",
			LevelKey:         "L",
			CallerKey:        "C",
			MessageKey:       "M",
			EncodeTime:       zapcore.ISO8601TimeEncoder,
			EncodeLevel:      zapcore.CapitalColorLevelEncoder,
			EncodeCaller:     zapcore.ShortCallerEncoder,
			ConsoleSeparator: " ",
		}
		consoleEnc := zapcore.NewConsoleEncoder(encCfg)
		ws := zapcore.Lock(os.Stdout)

		var level zapcore.Level
		if e := level.UnmarshalText([]byte(os.Getenv("LOG_LEVEL"))); e != nil {
			level = zapcore.InfoLevel
		}
		consoleCore := zapcore.NewCore(consoleEnc, ws, level)
		console = zap.New(consoleCore, zap.AddCaller())

		if s != nil {
			cfg := zapsentry.Configuration{
				Level:             zapcore.ErrorLevel,
				EnableBreadcrumbs: true,
				BreadcrumbLevel:   zapcore.InfoLevel,
				Tags: map[string]string{
					"environment": os.Getenv("ENVIRONMENT"),
				},
			}
			sentryCore, e2 := zapsentry.NewCore(cfg, zapsentry.NewSentryClientFromClient(s))
			if e2 != nil {
				panic("zapsentry.NewCore: " + e2.Error())
			}

			core := zapcore.NewTee(consoleCore, sentryCore)

			zl = zap.New(core, zap.AddCaller())
		} else {
			zl = zap.New(consoleCore, zap.AddCaller())
		}
	})
	return err
}

func L() *zap.Logger {
	return zl
}

func Console() *zap.Logger {
	return console
}

func Sync() error {
	if zl != nil {
		err := zl.Sync()
		sentry.Flush(2 * time.Second)
		return err
	}
	return nil
}
