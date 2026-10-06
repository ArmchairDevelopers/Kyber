use std::io::Sink;

use flutter_rust_bridge::for_generated::anyhow::bail;
use lazy_static::lazy_static;
use log::{debug, error, info, set_max_level, warn, LevelFilter};
use maxima::core::auth::context::AuthContext;
use maxima::core::auth::login::{begin_oauth_login_flow, manual_login};
use maxima::core::auth::{nucleus_auth_exchange, nucleus_token_exchange, TokenResponse};
use maxima::core::clients::JUNO_PC_CLIENT_ID;
use maxima::core::launch::{LaunchMode, LaunchOptions};
use maxima::core::service_layer::{ServiceGetBasicPlayerRequest, ServiceGetBasicPlayerRequestBuilder, ServiceGetUserPlayerRequestBuilder, ServiceLayerError, ServicePlayer as MaximaServicePlayer, ServicePlayersPage, ServiceSearchPlayerRequest, ServiceSearchPlayerRequestBuilder, ServiceUserGameProduct, SERVICE_REQUEST_GETBASICPLAYER, SERVICE_REQUEST_GETUSERPLAYER, SERVICE_REQUEST_SEARCHPLAYER};
use maxima::core::{launch, LockedMaxima, Maxima, MaximaEvent};
pub use maxima::rtm::client::BasicPresence;
use maxima::util::native::maxima_dir;
use maxima::util::registry::read_game_path;
#[cfg(windows)]
use maxima::{
    core::background_service::request_registry_setup,
    util::service::{is_service_running, is_service_valid, register_service_user, start_service},
};
use maxima::{
    core::service_layer::{ServiceFriends, ServiceGetMyFriendsRequestBuilder, SERVICE_REQUEST_GETMYFRIENDS},
    util::{log::init_logger, registry::check_registry_validity},
};
use regex::Regex;
use tokio::net::TcpListener;

use crate::frb_generated::{RustAutoOpaque, StreamSink};

pub struct ServiceImage {
    pub height: Option<u16>,
    pub width: Option<u16>,
    pub path: String,
}

pub struct ServiceAvatarList {
    pub small: ServiceImage,
    pub medium: ServiceImage,
    pub large: ServiceImage,
}

pub struct ServicePlayer {
    pub id: String,
    pub pd: String,
    pub psd: String,
    pub display_name: String,
    pub unique_name: String,
    pub nickname: String,
    pub avatar: Option<ServiceAvatarList>,
    pub relationship: String,
}

lazy_static! {
    static ref MANUAL_LOGIN_PATTERN: Regex = Regex::new(r"^(.*):(.*)$").unwrap();
}
static mut _maxima: Option<LockedMaxima> = None;
static mut _rpc_connected: bool = false;

async fn create_maxima_instance() {
    unsafe {
        _maxima = Some(Maxima::new().await.unwrap());
    }
}

fn maxima() -> &'static LockedMaxima {
    unsafe { _maxima.as_ref().unwrap() }
}

#[cfg(windows)]
pub async fn inject_kyber(pid: u32, path: String) -> anyhow::Result<()> {
    use maxima::core::background_service::request_library_injection;
    Ok(request_library_injection(pid, &path).await?)
}

#[cfg(not(windows))]
pub async fn inject_kyber(pid: u32, path: String) -> anyhow::Result<()> {
    Ok(())
}

fn convert_service_player(player: &MaximaServicePlayer) -> ServicePlayer {
    ServicePlayer {
        id: player.id().to_owned(),
        pd: player.pd().to_owned(),
        psd: player.psd().to_owned(),
        display_name: player.display_name().to_owned(),
        unique_name: player.unique_name().to_owned(),
        nickname: player.nickname().to_owned(),
        avatar: match player.avatar() {
            Some(avatar) => Some(ServiceAvatarList {
                small: ServiceImage {
                    height: avatar.small().height().to_owned(),
                    width: avatar.small().width().to_owned(),
                    path: avatar.small().path().to_owned(),
                },
                medium: ServiceImage {
                    height: avatar.medium().height().to_owned(),
                    width: avatar.medium().width().to_owned(),
                    path: avatar.medium().path().to_owned(),
                },
                large: ServiceImage {
                    height: avatar.large().height().to_owned(),
                    width: avatar.large().width().to_owned(),
                    path: avatar.large().path().to_owned(),
                },
            }),
            None => None,
        },
        relationship: player.relationship().to_string(),
    }
}

pub async fn get_friend_list() -> anyhow::Result<Vec<ServicePlayer>> {
    let maxima = maxima().lock().await;

    let response = maxima.friends(0).await?;

    let mut friends: Vec<ServicePlayer> = Vec::new();
    for player in response {
        friends.push(convert_service_player(&player));
    }

    return Ok(friends);
}

#[frb(mirror(BasicPresence), non_opaque)]
pub enum _BasicPresence {
    Unknown,
    Offline,
    Online,
    Dnd,
    Away,
}

#[frb(non_opaque)]
pub struct RtmPresence {
    pub player_id: String,
    pub basic: BasicPresence,
    pub status: String,
    pub game: Option<String>,
}

pub async fn set_rtm_presence(status: String) -> anyhow::Result<()> {
    let mut maxima = maxima().lock().await;
    maxima.rtm().set_presence(BasicPresence::Online, &status, "Origin.OFR.50.0002148").await?;
    drop(maxima);
    Ok(())
}

pub async fn start_rtm_connection() -> anyhow::Result<()> {
    unsafe {
        if _rpc_connected {
            return Ok(());
        }
    }

    let mut maxima_l = maxima().lock().await;
    let friends = maxima_l.friends(0).await?;
    let rtm = maxima_l.rtm();
    rtm.login().await?;
    rtm.set_presence(BasicPresence::Online, "KYBER", "Origin.OFR.50.0002148")
        .await?;

    let players: Vec<String> = friends
        .iter()
        .map(|f| f.id().to_owned())
        .collect();

    rtm.subscribe(&players).await?;
    drop(maxima_l);

    unsafe {
        _rpc_connected = true;
    }

    Ok(())
}

// pub async fn set_rtm_presence(
//     presence: BasicPresence,
//     status: String,
//     game: Option<String>,
// ) -> anyhow::Result<()> {
//     let mut maxima = maxima().lock().await;
//     maxima.rtm().set_presence(presence, &status, &game)
//         .await?;
//
//     drop(maxima);
//     Ok(())
// }

pub async fn get_rtm_presences(presence_sink: StreamSink<RtmPresence>) -> anyhow::Result<()> {
    tokio::spawn(async move {
        loop {
            let mut maxima = maxima().lock().await;
            maxima.rtm().heartbeat().await;
            {
                let store = maxima.rtm().presence_store().lock().await;
                for entry in store.iter() {
                    let is_closed = presence_sink.add(RtmPresence {
                        player_id: entry.0.to_owned().to_string(),
                        basic: entry.1.basic().to_owned(),
                        status: entry.1.status().to_owned(),
                        game: entry.1.game().to_owned(),
                    });

                    if is_closed.is_err() {
                        break;
                    }
                }
            }

            drop(maxima);
            tokio::time::sleep(std::time::Duration::from_secs(20)).await;
        }
    });

    return Ok(());
}

pub async fn lsx_get_event_stream(pid: u32, is_startup: Option<bool>, game_sink: StreamSink<String>) {
    let maxima_arc = maxima().clone();
    let timeout = if is_startup.is_none() {
        std::time::Duration::from_millis(25)
    } else {
        std::time::Duration::from_millis(100)
    };

    loop {
        let mut maxima = maxima_arc.lock().await;

        for event in maxima.consume_pending_events() {
            match event {
                MaximaEvent::ReceivedLSXRequest(e_pid, request) => {
                    if e_pid != pid {
                        continue;
                    }

                    let name: &'static str = request.into();
                    let is_closed = game_sink.add(name.to_string());
                    if is_closed.is_err() {
                        return;
                    }
                }
                _ => (),
            }
        }

        maxima.update().await;
        if maxima.playing().is_none() {
            break;
        }

        drop(maxima);
        tokio::time::sleep(timeout).await;
    }
}

pub async fn avatar_image(pd: &str, width: u16, height: u16) -> anyhow::Result<String> {
    let maxima_arc = maxima().clone();
    let mut maxima = maxima_arc.lock().await;

    let avatar = maxima.avatar_image(&pd, width, height).await?;

    Ok(avatar.to_str().unwrap().to_string())
}

pub async fn get_user(pd: String) -> anyhow::Result<ServicePlayer> {
    let maxima_arc = maxima().clone();
    let maxima = maxima_arc.lock().await;

    Ok(convert_service_player(&maxima.player_by_id(&pd).await?))
}

pub async fn search_user(name: String) -> anyhow::Result<ServicePlayer> {
    let maxima_arc = maxima().clone();
    let mut maxima = maxima_arc.lock().await;

    let response: Result<ServicePlayersPage, ServiceLayerError> = maxima
        .service_layer()
        .request(
            SERVICE_REQUEST_SEARCHPLAYER,
            ServiceSearchPlayerRequestBuilder::default()
                .is_mutual_friends_enabled(false)
                .page_number(1)
                .page_size(1)
                .search_text(name)
                .build()?,
        )
        .await;

    if let Err(err) = response {
        error!("Failed to search user by PD: {}", err);
        bail!(err);
    }

    let response = response?;
    
    if response.items().is_empty() {
        bail!("User not found");
    }
    
    let player = response.items().first().unwrap();
    Ok(convert_service_player(player))
}

pub async fn check_game_installation() -> anyhow::Result<()> {
    let maxima_arc = maxima().clone();
    let mut maxima = maxima_arc.lock().await;
    let game = maxima.mut_library().game_by_base_slug("star-wars-battlefront-2").await;
    if game.is_err() {
        bail!(game.err().unwrap())
    }

    let game = game?;
    if game.is_none() {
        bail!("Game not found");
    }

    let game = game.unwrap();
    if !game.is_installed().await {
        bail!("Game not installed");
    }

    Ok(())
}

pub async fn start_game(
    game_slug: String,
    game_path_override: Option<String>,
    game_args: Option<Vec<String>>,
) -> anyhow::Result<u32> {
    let maxima_arc = maxima().clone();

    let offer_id = {
        let mut maxima = maxima_arc.lock().await;
        let game = maxima.mut_library().game_by_base_slug(&game_slug).await;
        if game.is_err() {
            bail!(game.err().unwrap())
        }

        let game = game?;
        if game.is_none() {
            bail!("Game not found");
        }

        let game = game.unwrap();
        if !game.is_installed().await {
            bail!("Game not installed");
        }

        game.offer_id().to_owned()
    };

    // TODO: re-enable cloud-saves (@headassbtw please fix)
    launch::start_game(maxima_arc.clone(), LaunchMode::Online(offer_id), LaunchOptions {
        path_override: game_path_override,
        arguments: game_args.unwrap_or_default(),
        cloud_saves: false,
    }).await?;

    loop {
        let mut maxima = maxima_arc.lock().await;
        for event in maxima.consume_pending_events() {
            match event {
                MaximaEvent::ReceivedLSXRequest(pid, request) => {
                    let name: &'static str = request.into();
                    if name != "ChallengeResponse" {
                        continue;
                    }

                    debug!("Received ChallengeResponse from LSX for PID {}!", pid);

                    return Ok(pid);
                }
                _ => (),
            }
        }

        drop(maxima);
        tokio::time::sleep(std::time::Duration::from_millis(25)).await;
    }
}

fn is_maxima_running() -> bool {
    unsafe { _maxima.is_some() }
}

pub async fn check_game_ownership() -> anyhow::Result<bool> {
    let maxima_arc = maxima().clone();
    let mut maxima = maxima_arc.lock().await;

    let game = maxima.mut_library().game_by_base_slug("star-wars-battlefront-2").await;
    if game.is_err() {
        bail!(game.err().unwrap())
    }

    let game = game?;
    if game.is_none() {
        return Ok(false);
    }

    Ok(true)
}

async fn login(login_override: Option<String>) -> anyhow::Result<TokenResponse> {
    info!("Beginning login flow..");
    let mut auth_context = AuthContext::new()?;

    if let Some(access_token) = &login_override {
        let access_token = if let Some(captures) = MANUAL_LOGIN_PATTERN.captures(&access_token) {
            let persona = &captures[1];
            let password = &captures[2];

            let login_result = manual_login(persona, password).await;
            if login_result.is_err() {
                bail!("Login failed: {}", login_result.err().unwrap().to_string());
            }

            login_result.unwrap()
        } else {
            access_token.to_owned()
        };

        auth_context.set_access_token(&access_token);
        let code = nucleus_auth_exchange(&auth_context, JUNO_PC_CLIENT_ID, "code").await?;
        auth_context.set_code(&code);
    } else {
        info!("Beginning login flow..");
        begin_oauth_login_flow(&mut auth_context).await?
    };

    if auth_context.code().is_none() {
        bail!("Login failed!");
    }

    if login_override.is_none() {
        info!("Received login...");
    }

    let token_res = nucleus_token_exchange(&auth_context).await;
    if token_res.is_err() {
        bail!("Login failed: {}", token_res.err().unwrap().to_string());
    }

    let token_res = token_res?;
    Ok(token_res)
}

pub async fn get_auth_token() -> String {
    let y = maxima().lock().await;
    {
        let mut auth_storage = y.auth_storage().lock().await;
        let token = auth_storage.access_token().await;
        return token.unwrap().unwrap();
    }
}

#[frb(sync)]
pub fn get_game_dir(game_slug: String) -> String {
    let result = read_game_path(&game_slug);

    match result {
        Ok(path) => path.to_str().unwrap().to_string(),
        Err(_) => "".to_string(),
    }
}

pub async fn is_logged_in() -> bool {
    let y = maxima().lock().await;
    {
        let mut auth_storage = y.auth_storage().lock().await;
        let logged_in = auth_storage.logged_in().await;
        return logged_in.unwrap_or(false);
    }
}

/// Starts the login flow. When not logged in, will start EA OAuth2 login flow. When logged in, will return the current player as [ServicePlayer].
///
/// [login_override] - When set, will override the login flow and use the provided credentials instead. Format: persona:password
pub async fn login_flow(login_override: Option<String>) -> anyhow::Result<ServicePlayer> {
    let y = maxima().lock().await;
    {
        let mut auth_storage = y.auth_storage().lock().await;
        let logged_in = auth_storage.logged_in().await?;
        if !logged_in || login_override.is_some() {
            info!("Logging in...");
            let token_res = login(login_override).await?;
            auth_storage.add_account(&token_res).await?;
        }
    }

    let local_user = y.local_user().await?;
    let user = local_user.player().as_ref().unwrap();

    Ok(convert_service_player(&user))
}

#[cfg(windows)]
pub async fn check_service() -> anyhow::Result<()> {
    if !is_service_running()? {
        info!("Starting service...");
        start_service().await?;
    }

    Ok(())
}

#[cfg(not(windows))]
pub async fn check_service() -> anyhow::Result<()> {
    Ok(())
}

#[cfg(windows)]
async fn native_setup() -> anyhow::Result<()> {
    if !is_service_valid()? {
        info!("Installing service...");
        register_service_user()?;
        tokio::time::sleep(std::time::Duration::from_secs(1)).await;
    }

    if !is_service_running()? {
        info!("Starting service...");
        start_service().await?;
    }

    if let Err(err) = check_registry_validity() {
        warn!("{}, fixing...", err);
        request_registry_setup().await?;
    }

    Ok(())
}

#[cfg(not(windows))]
async fn native_setup() -> anyhow::Result<()> {
    use maxima::util::registry::set_up_registry;

    if let Err(err) = check_registry_validity() {
        warn!("{}, fixing...", err);
        set_up_registry()?;
    }

    Ok(())
}

/// Starts Maxima.
///
/// [enable_logger] - Whether to enable logging. Defaults to false. (Attention: Logging breaks Flutter's Hot Reload/Restart)
pub async fn start_maxima(
    enable_logger: Option<bool>
) -> anyhow::Result<()> {
    if is_maxima_running() {
        return Ok(());
    }

    native_setup().await?;
    create_maxima_instance().await;

    let lsx_port = {
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        listener.local_addr().unwrap().port()
    };

    maxima().lock().await.set_lsx_port(lsx_port);

    let maxima_arc = maxima().clone();
    {
        let maxima = maxima_arc.lock().await;
        maxima.start_lsx(maxima_arc.clone()).await?;
    }

    Ok(())
}

#[frb(init)]
pub fn init_app() {
    // Default utilities - feel free to customize
    flutter_rust_bridge::setup_default_user_utils();
}

flutter_logger::flutter_logger_init!(LevelFilter::Debug);
