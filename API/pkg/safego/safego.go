package safego

import (
	"time"

	"github.com/getsentry/sentry-go"
)

func Go(fn func()) {
	go func() {
		defer func() {
			if r := recover(); r != nil {
				sentry.CurrentHub().Recover(r)
				sentry.Flush(2 * time.Second)
				panic(r)
			}
		}()
		fn()
	}()
}
