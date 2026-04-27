FROM golang:1.25-alpine AS tools

RUN apk add --no-cache git bash

RUN go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.36.6 \
    && go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.5.1 \
    && go install github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-grpc-gateway@v2.26.3 \
    && go install github.com/bufbuild/buf/cmd/buf@v1.68.4

FROM golang:1.25-alpine AS builder

RUN apk add --no-cache bash
COPY --from=tools /go/bin/protoc-gen-go            /go/bin/
COPY --from=tools /go/bin/protoc-gen-go-grpc       /go/bin/
COPY --from=tools /go/bin/protoc-gen-grpc-gateway  /go/bin/
COPY --from=tools /go/bin/buf                      /go/bin/

WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY . .
COPY --from=base Module/Proto /Module/Proto

RUN buf generate

RUN CGO_ENABLED=0 GOOS=linux go build \
    -ldflags="-s -w" \
    -o kyber-api \
    ./cmd/server

FROM alpine:latest

RUN apk add --no-cache ca-certificates

RUN addgroup -S kyber && adduser -S kyber -G kyber

WORKDIR /app
COPY --from=builder /src/kyber-api .

EXPOSE 9027 8080

USER kyber
ENTRYPOINT ["./kyber-api"]
