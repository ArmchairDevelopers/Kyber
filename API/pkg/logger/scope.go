package logger

import (
	"bytes"
	"runtime"
	"sync"

	"github.com/TheZeroSlave/zapsentry"
	"github.com/getsentry/sentry-go"
	"go.uber.org/zap/zapcore"
)

var scopes sync.Map

func BindScope(scope *sentry.Scope) func() {
	id := goroutineID()
	scopes.Store(id, scope)

	return func() {
		scopes.Delete(id)
	}
}

func goroutineID() string {
	var buf [64]byte
	return string(bytes.Fields(buf[:runtime.Stack(buf[:], false)])[1])
}

type scopedCore struct {
	zapcore.Core
}

func (c scopedCore) Check(ent zapcore.Entry, ce *zapcore.CheckedEntry) *zapcore.CheckedEntry {
	if c.Enabled(ent.Level) {
		return ce.AddCore(ent, c)
	}

	return ce
}

func (c scopedCore) Write(ent zapcore.Entry, fields []zapcore.Field) error {
	if scope, ok := scopes.Load(goroutineID()); ok {
		return c.Core.With([]zapcore.Field{zapsentry.NewScopeFromScope(scope.(*sentry.Scope))}).Write(ent, fields)
	}

	return c.Core.Write(ent, fields)
}
