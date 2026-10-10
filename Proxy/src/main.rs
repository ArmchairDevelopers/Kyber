use log::{debug, error, info, warn};
use std::env;
use std::error::Error;
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::mpsc;
use tokio_tungstenite::{
    accept_hdr_async,
    tungstenite::{
        handshake::server::{Request, Response},
        Message,
    },
};
use user_manager::UserManager;
use std::time::{Duration, Instant};
use jsonwebtoken::{decode, decode_header, Validation, Algorithm};
use serde::{Deserialize, Serialize};
use percent_encoding::percent_decode_str;
use jwks::JwksManager;
use std::sync::Arc;

mod grpc_client;
mod user_manager;
mod utils;
mod jwks;

use futures_util::{SinkExt, StreamExt};

use crate::utils::prepend_identifier;

const SERVER_RECONNECT_TIMEOUT: Duration = Duration::from_secs(10);

#[derive(Debug, Serialize, Deserialize)]
struct Claims {
    sub: Option<String>,
    server_id: Option<String>,
    user_id: Option<String>,
    exp: usize,
    iat: Option<usize>,
    #[serde(flatten)]
    extra: serde_json::Map<String, serde_json::Value>,
}

async fn validate_jwt_token(token: &str, jwks_manager: &JwksManager) -> Result<Claims, Box<dyn Error + Send + Sync>> {
    let header = decode_header(token)?;

    let kid = header.kid.ok_or_else(|| -> Box<dyn Error + Send + Sync> {
        Box::from("JWT token missing 'kid' in header")
    })?;

    let decoding_key = jwks_manager.get_key(&kid).await?;

    let mut validation = Validation::new(Algorithm::RS256);
    validation.validate_exp = true;
    validation.validate_nbf = false;

    let token_data = decode::<Claims>(token, &*decoding_key, &validation)?;
    Ok(token_data.claims)
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    env_logger::init();

    let _guard = sentry::init((env::var("SENTRY_DSN").ok(), sentry::ClientOptions {
        release: sentry::release_name!(),
        send_default_pii: true,
        ..Default::default()
    }));

    let server_ip = env::var("SERVER_IP").unwrap_or_else(|_| "0.0.0.0".to_string());
    let server_port = env::var("SERVER_PORT").unwrap_or_else(|_| "8080".to_string());
    let addr = format!("{}:{}", server_ip, server_port);

    let jwks_url = env::var("JWKS_URL").unwrap();
    let jwks_manager = Arc::new(JwksManager::new(jwks_url.clone()));

    info!("Pre-fetching JWKS from {}", jwks_url);
    jwks_manager.refresh_jwks_safe().await;

    let refresh_interval = Duration::from_secs(3600);
    jwks_manager.clone().start_periodic_refresh(refresh_interval);
    info!("Started periodic JWKS refresh (every {} seconds)", refresh_interval.as_secs());

    let socket = TcpListener::bind(&addr).await?;
    info!("Listening on: {}", socket.local_addr()?);

    let user_manager = UserManager::new();

    while let Ok((stream, _)) = socket.accept().await {
        let cloned = user_manager.clone();
        let jwks_manager_clone = jwks_manager.clone();
        tokio::spawn(async move {
            let _ = accept_connection(stream, cloned, jwks_manager_clone).await;
        });
    }

    info!("Server shutting down");
    Ok(())
}

async fn accept_connection(stream: TcpStream, user_manager: UserManager, jwks_manager: Arc<JwksManager>) {
    if stream.set_nodelay(true).is_err() {
        warn!("Failed to set nodelay on stream, closing");
        return;
    }

    let mut uri = None;
    let mut token_header = None;
    let mut server_disconnect_time: Option<Instant> = None;

    let callback = |req: &Request, response: Response| {
        uri = Some(req.uri().clone());
        if let Some(token_values) = req.headers().get("Authorization") {
            if let Ok(token_str) = token_values.to_str() {
                token_header = Some(token_str.to_string());
            }
        }
        Ok(response)
    };

    let ws_stream = accept_hdr_async(stream, callback).await;
    if ws_stream.is_err() {
        return;
    }

    let mut ws_stream = ws_stream.unwrap();

    let uri = uri.unwrap();

    if uri.path().starts_with("/ping") {
        loop {
            let msg = ws_stream.next().await;
            if msg.is_none() {
                break;
            }

            let msg = msg.unwrap();
            if msg.is_err() {
                break;
            }

            let msg = msg.unwrap();
            if msg.is_text() {
                let msg = msg.to_text();
                if msg.is_err() {
                    break;
                }

                let msg = msg.unwrap();
                if msg == "PING" {
                    ws_stream.send(Message::text("PONG")).await.ok();
                }
            }
        }

        return;
    }

    let server_mode = uri.path().starts_with("/server");

    let token = match token_header {
        Some(token) => token,
        None => {
            warn!("No token provided in connection URL");
            ws_stream.close(None).await.ok();
            return;
        }
    };

    let claims = match validate_jwt_token(&token, &jwks_manager).await {
        Ok(claims) => claims,
        Err(e) => {
            warn!("Invalid JWT token: {}", e);
            ws_stream.close(None).await.ok();
            return;
        }
    };

    let server_id = claims.server_id.as_deref()
        .filter(|s| !s.is_empty());
    if server_id.is_none() {
        warn!("No server_id found in JWT claims");
        ws_stream.close(None).await.ok();
        return;
    }

    let server_id = server_id.unwrap();

    info!(
        "{} mode for server_id: {}",
        if server_mode { "Server" } else { "Client" },
        server_id
    );

    if !server_mode {
        if server_id.is_empty() {
            warn!("No server_id found in JWT claims or query parameter");
            ws_stream.close(None).await.ok();
            return;
        }

        let server = user_manager.get_server_by_id(server_id);
        if server.is_none() {
            warn!("Server not found for id: {}", server_id);
            ws_stream.close(None).await.ok();
            return;
        }

        let mut server = server.unwrap();

        let converted_token = user_manager.convert_token(&token);
        let existing_user = user_manager.get_user_by_id(converted_token);
        if let Some(user) = existing_user {
            warn!("User with token already connected: {}", converted_token);
            let _ = user.cancel_token.send(());
            user_manager.remove_user(converted_token);
        }

        let (mut write, mut read) = ws_stream.split();
        let (tx, mut rx) = mpsc::unbounded_channel();
        let (cancel_tx, _cancel_rx) = mpsc::unbounded_channel();
        let user_id = user_manager.add_user(tx, cancel_tx, server_id, token);

        loop {
            tokio::select! {
                msg = read.next() => {
                    if let Some(Ok(msg)) = msg {
                        if msg.is_binary() || msg.is_text() {
                            let modified_packet = prepend_identifier(&msg.into_data(), user_id);
                            let result = server.sender.send(Message::binary(modified_packet.clone()));
                            if let Err(err) = result {
                                let new_server = user_manager.get_server_by_id(server_id);
                                if new_server.is_none() {
                                    if server_disconnect_time.is_none() {
                                        server_disconnect_time = Some(Instant::now());
                                        warn!("Server {} disconnected, starting reconnection timeout", server_id);
                                    } else if let Some(disconnect_time) = server_disconnect_time {
                                        if disconnect_time.elapsed() > SERVER_RECONNECT_TIMEOUT {
                                            warn!("Server {} reconnection timeout exceeded", server_id);
                                            break;
                                        }
                                    }
                                } else {
                                    server_disconnect_time = None;
                                    server = new_server.unwrap();
                                    server.sender.send(Message::binary(modified_packet)).ok();
                                }
                            }
                        } else {
                            debug!("Client on non-bin message: {:?}", &msg);
                        }
                    } else {
                        break;
                    }
                }
                packet = rx.recv() => {
                    if let Some(packet) = packet {
                        let result = write.send(packet).await;
                        if let Err(err) = result {
                            error!("Failed to send packet to client {}: {}", user_id, err);
                        }
                    } else {
                        break;
                    }
                }
            }
        }

        info!("Client disconnecting: {}", server_id);

        user_manager.remove_user(user_id);

        info!("Client disconnected: {}", server_id);
    } else {
        if let Some(server) = user_manager.get_server_by_id(server_id) {
            warn!("Server already exists for id {}, overwriting", server_id);

            if let Err(err) = server.cancel_token.send(()) {
                error!("Failed to cancel connection for server {}: {}", server_id, err);
            }
        }

        let (mut write, mut read) = ws_stream.split();
        let (tx, mut rx) = mpsc::unbounded_channel();
        let (cancel_tx, mut cancel_rx) = mpsc::unbounded_channel();

        user_manager.add_server(tx, cancel_tx, server_id);

        let mut remove_server = true;

        loop {
            tokio::select! {
                msg = read.next() => {
                    if let Some(Ok(msg)) = msg {
                        if msg.is_binary() || msg.is_text() {
                            let (identifier, modified_packet) = utils::extract_identifier(&msg.into_data());
                            if let Some(user) = user_manager.get_user_by_id(identifier) {
                                let result = user.sender.send(Message::binary(modified_packet));
                                if let Err(err) = result {
                                    error!("Failed to send packet to user {}: {}", identifier, err);
                                }
                            }
                        } else {
                            debug!("Server on non-bin message: {:?}", &msg);
                        }
                    } else {
                        break;
                    }
                }
                packet = rx.recv() => {
                    if let Some(packet) = packet {
                        let result = write.send(packet).await;
                        if let Err(err) = result {
                            error!("Failed to send packet {}: {}", server_id, err);
                        }
                    } else {
                        break;
                    }
                }
                _ = cancel_rx.recv() => {
                    remove_server = false;
                    break;
                }
            }
        }

        info!("Server disconnecting: {}", server_id);

        if remove_server {
            user_manager.remove_server(server_id);
        }

        info!("Server disconnected: {}", server_id);
    }
}
