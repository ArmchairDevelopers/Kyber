FROM rustlang/rust:nightly-bookworm-slim AS builder

# Install dependencies
RUN apt-get -y update
RUN apt-get -y install pkg-config libssl-dev unzip curl build-essential

# Set up protoc
WORKDIR /home/proto
RUN curl -LO https://github.com/protocolbuffers/protobuf/releases/download/v25.0/protoc-25.0-linux-x86_64.zip
RUN unzip protoc-25.0-linux-x86_64.zip
ENV PROTOC=/home/proto/bin/protoc

WORKDIR /home/kyber_proxy

RUN mkdir -p /home/kyber_proxy/Module
COPY --from=base Module/Proto /home/kyber_proxy/Module/Proto

RUN mkdir -p /home/kyber_proxy/Proxy
COPY Cargo.toml /home/kyber_proxy/Proxy/.
WORKDIR /home/kyber_proxy/Proxy

RUN echo "fn main() {}" > dummy.rs
RUN sed -i 's#src/main.rs#dummy.rs#' Cargo.toml

RUN cargo build --release
RUN sed -i 's#dummy.rs#src/main.rs#' Cargo.toml

COPY . /home/kyber_proxy/Proxy
RUN cargo install --path .

FROM debian:bookworm-slim

RUN apt-get update -y && apt-get -y install ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=builder /usr/local/cargo/bin/kyber_proxy /usr/local/bin/kyber_proxy

EXPOSE 8080

CMD ["kyber_proxy"]
