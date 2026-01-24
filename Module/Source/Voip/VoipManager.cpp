#include <Base/Pch.h>
#include <Voip/VoipManager.h>
#include <Core/Console.h>
#include <Core/Program.h>
#include <SDK/Funcs.h>

#include <Vxc.h>
#include <VxcErrors.h>

#include <cstdio>
#include <numbers>
#include <string>
#include <cmath>

#define KYBER_PI 3.1415926535897932384626433832795

namespace Kyber
{
void OnLog(void* callback_handle, vx_log_level level, const char* source, const char* message)
{
    KYBER_LOG(Info, "[Vivox] " << source << ": " << message);
}

void OnSdkMessageAvailable(void* callbackHandle)
{
    VoipManager* manager = reinterpret_cast<VoipManager*>(callbackHandle);
    manager->Wakeup();
}

void VoipMuteCommand(ConsoleContext& cc)
{
    VoipManager* manager = g_program->m_voipManager;
    manager->SetMuted(true);
}

void VoipListCaptureDevicesCommand(ConsoleContext& cc)
{
    VoipManager* manager = g_program->m_voipManager;
    cc << "Capture devices:\n";

    int i = 0;
    for (const auto& device : manager->GetCaptureDevices())
    {
        std::string idx = std::to_string(i++);
        cc << idx << ": " << device.displayName << "\n";
    }

    cc << "Select with Kyber.VoipSetCaptureDevice <id>";
}

void VoipSetCaptureDeviceCommand(ConsoleContext& cc)
{
    VoipManager* manager = g_program->m_voipManager;

    auto stream = cc.stream();
    int id;
    stream >> id;

    const auto& device = manager->GetCaptureDevices()[id];
    cc << "Changing capture device to " << device.displayName;

    manager->SetCaptureDevice(device.identifier);
}

void VoipSetInputVolumeCommand(ConsoleContext& cc)
{
    VoipManager* manager = g_program->m_voipManager;

    auto stream = cc.stream();
    float volume;
    stream >> volume;

    cc << "Changing input volume to " << volume;
    manager->SetInputVolume(volume);
}

void VoipSetSpeakerVolumeCommand(ConsoleContext& cc)
{
    VoipManager* manager = g_program->m_voipManager;

    auto stream = cc.stream();
    float volume;
    stream >> volume;

    cc << "Changing speaker volume to " << volume;
    manager->SetSpeakerVolume(volume);
}

bool VoipManager::IsParticipantSpeaking(const char* playerName)
{
    auto participantsGuard = m_participants.Lock();

    std::string playerNameStr = std::string(".") + playerName + ".";
    for (const auto& [uri, state] : *participantsGuard)
    {
        if (uri.find(playerNameStr) != std::string::npos)
        {
            return state.isSpeaking;
        }
    }
    
    return false;
}

float VoipManager::GetParticipantAudioEnergy(const char* playerName)
{
    auto participantsGuard = m_participants.Lock();

    std::string playerNameStr = std::string(".") + playerName + ".";
    for (const auto& [uri, state] : *participantsGuard)
    {
        if (uri.find(playerNameStr) != std::string::npos)
        {
            return state.audioEnergy;
        }
    }
    
    return 0.0f;
}

VoipManager::VoipManager()
{
    RegisterRenderListener(this);

    g_program->RegisterClientUpdatePassListener(this);
    g_program->m_consoleRegistrationCallbacks.push_back([&]() {
        RegisterConsoleCommand(&VoipMuteCommand, "VoipMute", "");
        RegisterConsoleCommand(&VoipListCaptureDevicesCommand, "VoipListCaptureDevices", "");
        RegisterConsoleCommand(&VoipSetCaptureDeviceCommand, "VoipSetCaptureDevice", "<id [from VoipListCaptureDevices]>");
        RegisterConsoleCommand(&VoipSetInputVolumeCommand, "VoipSetInputVolume", "<volume [0-100, default=50, logarithmic/sensitive]>");
        RegisterConsoleCommand(&VoipSetSpeakerVolumeCommand, "VoipSetOutputVolume", "<volume [0-100, default=50, logarithmic/sensitive]>");
    });

    ConvertOrientation(0, 0);
}

void VoipManager::Init()
{
    vx_sdk_config_t config;
    int status = vx_get_default_config3(&config, sizeof(config));

    config.pf_logging_callback = OnLog;
    config.pf_sdk_message_callback = OnSdkMessageAvailable;
    config.callback_handle = this;

    if (status != VxErrorSuccess)
    {
        printf("vx_sdk_get_default_config3() returned %d: %s\n", status, vx_get_error_string(status));
        return;
    }

    status = vx_initialize3(&config, sizeof(config));

    if (status != VxErrorSuccess)
    {
        printf("vx_initialize3() returned %d : %s\n", status, vx_get_error_string(status));
        return;
    }

    vxplatform::create_event(&m_messageAvailableEvent);
    vxplatform::create_thread(&VoipManager::ListenerThread, this, &m_listenerThread, &m_listenerThreadId);
    vxplatform::create_thread(&VoipManager::PositionUpdateThread, this, &m_positionUpdateThread, &m_positionUpdateThreadId);
    KYBER_LOG(Info, "[VoIP] Initialized Vivox SDK");

    RequestLogin();
}

void VoipManager::RequestLogin()
{
    KYBER_LOG(Info, "[VoIP] Requesting vivox login...");
    g_program->GetAPI()->GetVoip()->Login([&](std::optional<const VoipLoginResponse*> response) {
        if (!response)
        {
            KYBER_LOG(Error, "[VoIP] Failed to retrieve vivox credentials. Proximity chat will not work!");
            return;
        }

        KYBER_LOG(Info, "[VoIP] Received vivox login, connecting...");

        m_username = (*response)->username();
        m_displayName = (*response)->displayname();
        m_issuer = (*response)->issuer();
        m_domain = (*response)->domain();

        Connect(vx_strdup((*response)->token().c_str()));

        KYBER_LOG(Info, "[VoIP] Post login complete");
        m_isPostLogin = true;
    });
}

void VoipManager::Wakeup()
{
    vxplatform::set_event(m_messageAvailableEvent);
}

vxplatform::os_error_t VoipManager::ListenerThread(void* arg)
{
    reinterpret_cast<VoipManager*>(arg)->ListenerThread();
    return 0;
}

vxplatform::os_error_t VoipManager::PositionUpdateThread(void* arg)
{
    reinterpret_cast<VoipManager*>(arg)->PositionUpdateThread();
    return 0;
}

void VoipManager::ListenerThread()
{
    while (true)
    {
        vxplatform::wait_event(m_messageAvailableEvent, -1);

        while (true)
        {
            vx_message_base_t* msg = NULL;
            vx_get_message(&msg);
            if (msg == NULL)
            {
                break;
            }

            HandleMessage(msg);
            vx_destroy_message(msg);
        }
    }
}

void VoipManager::PositionUpdateThread()
{
    while (true)
    {
        m_mutex.lock();
        if (m_currentChannel.empty())
        {
            m_mutex.unlock();
            Sleep(1000);
            continue;
        }

        if (!m_location.valid)
        {
            m_mutex.unlock();
            Sleep(1000);
            continue;
        }

        vx_req_session_set_3d_position_t* req;
        vx_req_session_set_3d_position_create(&req);
        req->req_disposition_type = req_disposition_no_reply_required;
        req->session_handle = vx_strdup(m_currentChannel.c_str());

        req->listener_position[0] = m_location.cameraX;
        req->listener_position[1] = m_location.cameraY;
        req->listener_position[2] = m_location.cameraZ;

        req->listener_at_orientation[0] = m_orientation.at_x;
        req->listener_at_orientation[1] = m_orientation.at_y;
        req->listener_at_orientation[2] = m_orientation.at_z;

        req->listener_up_orientation[0] = m_orientation.up_x;
        req->listener_up_orientation[1] = m_orientation.up_y;
        req->listener_up_orientation[2] = m_orientation.up_z;

        req->speaker_position[0] = m_location.x;
        req->speaker_position[1] = m_location.y;
        req->speaker_position[2] = m_location.z;

        m_mutex.unlock();
        SendRequest(&req->base);
        Sleep(67); // About 15 updates/sec
    }
}

void VoipManager::ConvertOrientation(float yaw, float pitch)
{
    // Convert yaw from [0, -2PI] to [0, 2PI]
    double yawNormalized = std::abs(yaw);

    // Convert pitch from [-1.5, 1.5] to [-PI/2, PI/2]
    double pitchNormalized = pitch * (std::numbers::pi / 2.0) / 1.5;

    double Fx = -cos(pitchNormalized) * sin(yawNormalized);
    double Fy = sin(pitchNormalized);
    double Fz = cos(pitchNormalized) * cos(yawNormalized);

    m_orientation = { Fx, Fy, Fz, 0, 1, 0 };
}

void VoipManager::Call(ClientUpdatePass pass)
{
    if (pass != ClientUpdatePass_PreFrame)
    {
        return;
    }

    if (g_program->m_clientState != ClientState_Ingame)
    {
        return;
    }

    if (m_pushToTalkEnabled)
    {
        bool isKeyPressed = GetAsyncKeyState(m_pushToTalkKey) & 0x8000;
        SetPushToTalkPressed(isKeyPressed);
    }

    m_mutex.lock();
    if (m_currentChannel.empty())
    {
        m_mutex.unlock();
        return;
    }

    ClientPlayerManager* playerManager = ClientGameContext::Get()->GetPlayerManager();
    if (playerManager == nullptr)
    {
        m_location.valid = false;
        m_mutex.unlock();
        return;
    }

    ClientPlayer* player = playerManager->GetLocalPlayer(LocalPlayerId_0);
    if (player == nullptr)
    {
        m_location.valid = false;
        m_mutex.unlock();
        return;
    }

    ClientSoldierEntity* entity = player->controlledControllable;
    if (entity == nullptr)
    {
        m_location.valid = false;
        m_mutex.unlock();
        return;
    }

    if (!entity->getType()->isKindOf(typeInfo_WSClientSoldierEntity))
    {
        m_location.valid = false;
        m_mutex.unlock();
        return;
    }

    if (entity->clientSoldierPrediction == nullptr)
    {
        m_location.valid = false;
        m_mutex.unlock();
        return;
    }

    LinearTransform cameraTransform;
    ClientCameraViewManager_getActiveCameraTransform(player->cameraViewManager, cameraTransform);

    Vec3& location = entity->clientSoldierPrediction->Location;
    // KYBER_LOG(Info, "Player X: " << location.x << " Y: " << location.y << " Z: " << location.z << " Yaw: " << entity->Yaw
    //                              << " Pitch: " << entity->Pitch << " " << std::hex << player);
    // KYBER_LOG(Info, "Camera X: " << cameraTransform.trans.x << " Y: " << cameraTransform.trans.y << " Z: " << cameraTransform.trans.z);

    m_location.x = location.x;
    m_location.y = location.y + 1;
    m_location.z = location.z;

    m_location.cameraX = cameraTransform.trans.x;
    m_location.cameraY = cameraTransform.trans.y;
    m_location.cameraZ = cameraTransform.trans.z;

    ConvertOrientation(entity->Yaw, entity->Pitch);

    m_location.valid = true;
    m_mutex.unlock();
}

void VoipManager::Render()
{
    // std::lock_guard<std::mutex> lock(m_mutex);
    
    // Vec3 firstPoint;
    // firstPoint.x = m_location.x;
    // firstPoint.x = m_location.y;
    // firstPoint.x = m_location.z;
    // Vec3 secondPoint;
    // secondPoint.x = m_location.x;
    // secondPoint.x = m_location.y + 200;
    // secondPoint.x = m_location.z;

    // DebugRenderer::current()->drawLine(firstPoint, secondPoint, { 255, 255, 255, 255 });
}

void VoipManager::HandleMessage(vx_message_base_t* msg)
{
    if (msg->type == msg_response)
    {
        vx_resp_base_t* resp = reinterpret_cast<vx_resp_base_t*>(msg);
        if (resp->return_code == 1)
        {
            KYBER_LOG(Debug, "[VoIP] Response " << vx_get_response_type_string(resp->type) << " returned '"
                                        << vx_get_error_string(resp->status_code) << "' (" << resp->status_code << ")");

            char* xml = NULL;
            vx_response_to_xml(resp, &xml);

            if (xml != nullptr)
            {
                KYBER_LOG(Debug, "[VoIP] Response: " << xml);
                vx_free(xml);
            }

            return;
        }
        else
        {
            KYBER_LOG(Debug, "[VoIP] Request " << vx_get_request_type_string(resp->request->type) << " completed");
        }

        switch (resp->type)
        {
        case resp_connector_create: {
            vx_resp_connector_create_t* tresp = (vx_resp_connector_create_t*)resp;
            m_connectorHandle = tresp->connector_handle;
            Login(reinterpret_cast<char*>(resp->request->vcookie));
            break;
        }
        case resp_account_anonymous_login: {
            vx_resp_account_anonymous_login_t* tresp = (vx_resp_account_anonymous_login_t*)resp;
            m_accountHandle = tresp->account_handle;
            break;
        }
        case resp_aux_get_capture_devices: {
            vx_resp_aux_get_capture_devices_t* tresp = reinterpret_cast<vx_resp_aux_get_capture_devices_t*>(resp);

            m_captureDevices.clear();
            for (int i = 0; i < tresp->count; i++)
            {
                vx_device_t* vxDevice = tresp->capture_devices[i];
                VoipDevice device = { vxDevice->device, vxDevice->display_name };
                m_captureDevices.push_back(device);
            }
            break;
        }
        case resp_aux_get_render_devices: {
            vx_resp_aux_get_render_devices_t* tresp = reinterpret_cast<vx_resp_aux_get_render_devices_t*>(resp);

            m_renderDevices.clear();
            for (int i = 0; i < tresp->count; i++)
            {
                vx_device_t* vxDevice = tresp->render_devices[i];
                VoipDevice device = { vxDevice->device, vxDevice->display_name };
                m_renderDevices.push_back(device);
            }
            break;
        }
        default:
            return;
        }
    }

    if (msg->type == msg_event)
    {
        vx_evt_base_t* evt = reinterpret_cast<vx_evt_base_t*>(msg);
        KYBER_LOG(Debug, "Event received: " << vx_get_event_type_string(evt->type));

        switch (evt->type)
        {
        case evt_account_login_state_change: {
            vx_evt_account_login_state_change* tevt = (vx_evt_account_login_state_change*)evt;
            if (tevt->status_code)
            {
                KYBER_LOG(Error, vx_get_event_type_string(evt->type)
                                     << ": " << tevt->account_handle << " " << vx_get_login_state_string(tevt->state) << " "
                                     << vx_get_error_string(tevt->status_code));
            }
            else
            {
                KYBER_LOG(Debug, vx_get_event_type_string(evt->type)
                                    << " " << tevt->account_handle << " " << vx_get_login_state_string(tevt->state));
            }

            if (login_state_logged_out == tevt->state)
            {
                // TODO
            }

            if (login_state_logged_in == tevt->state)
            {
                AuxGetCaptureDevices();
                AuxGetRenderDevices();
            }

            break;
        }
        case evt_media_stream_updated: {
            vx_evt_media_stream_updated* tevt = (vx_evt_media_stream_updated*)evt;

            KYBER_LOG(Debug, vx_get_event_type_string(evt->type)
                                << ": " << tevt->session_handle << " " << vx_get_session_media_state_string(tevt->state) << " '"
                                << vx_get_error_string(tevt->status_code) << "' (" << tevt->status_code << ")");
            break;
        }
        case evt_presence_updated: {
            vx_evt_presence_updated* tevt = (vx_evt_presence_updated*)evt;
            KYBER_LOG(Debug, vx_get_event_type_string(evt->type)
                                << ": " << tevt->sender_uri << " -> " << vx_get_self_presence_state_string(tevt->presence));
            break;
        }
        case evt_participant_updated: {
            vx_evt_participant_updated* tevt = (vx_evt_participant_updated*)evt;

            if (tevt->is_speaking) 
            {
                KYBER_LOG(Debug, "Participant " << tevt->participant_uri 
                        << " is speaking (energy: " << tevt->energy << ")");
            }

            {
                auto participantsGuard = m_participants.Lock();

                VoipParticipantState& participant = (*participantsGuard)[tevt->participant_uri];
                participant.uri = tevt->participant_uri;
                participant.isSpeaking = tevt->is_speaking;
                participant.audioEnergy = tevt->energy;
                participant.isMuted = tevt->is_muted_for_me || tevt->is_moderator_muted;
            }

            std::stringstream optionalPrintouts;
            if (tevt->has_unavailable_capture_device)
            {
                optionalPrintouts << " has_unavailable_capture_device = true";
            }
            if (tevt->has_unavailable_render_device)
            {
                optionalPrintouts << " has_unavailable_render_device = true";
            }
            if (tevt->diagnostic_state_count > 0)
            {
                optionalPrintouts << " diagnostic_states = [ ";
            }
            for (int i = 0; i < tevt->diagnostic_state_count; ++i)
            {
                vx_participant_diagnostic_state_t diagnosticState = (vx_participant_diagnostic_state_t)tevt->diagnostic_states[i];
                switch (diagnosticState)
                {
                case participant_diagnostic_state_speaking_while_mic_muted:
                    optionalPrintouts << "speaking_while_mic_muted";
                    break;
                case participant_diagnostic_state_speaking_while_mic_volume_zero:
                    optionalPrintouts << "speaking_while_mic_volume_zero";
                    break;
                case participant_diagnostic_state_no_capture_device:
                    optionalPrintouts << "no_capture_device";
                    break;
                case participant_diagnostic_state_no_render_device:
                    optionalPrintouts << "no_render_device";
                    break;
                case participant_diagnostic_state_capture_device_read_errors:
                    optionalPrintouts << "capture_device_read_errors";
                    break;
                case participant_diagnostic_state_render_device_write_errors:
                    optionalPrintouts << "render_device_write_errors";
                    break;
                }
                optionalPrintouts << " ";
            }
            if (tevt->diagnostic_state_count > 0)
            {
                optionalPrintouts << "]";
            }
            //printf("* %s: %s %s [speaking = %d energy = %.2f is_moderator_muted = %s is_muted_for_me = %s%s]\n",
            //   vx_get_event_type_string(evt->type), tevt->session_handle, tevt->participant_uri, tevt->is_speaking, tevt->energy,
            //   tevt->is_moderator_muted ? "true" : "false", tevt->is_muted_for_me ? "true" : "false", optionalPrintouts.str().c_str());
            break;
        }
        case evt_session_removed: {
            vx_evt_session_removed* tevt = (vx_evt_session_removed*)evt;
            m_currentChannel.clear();
        }
        default:
            return;
        }
    }
}

void VoipManager::SendRequest(vx_req_base_t* req)
{
    static int requestId = 0;
    std::string nextId = std::to_string(requestId++);
    req->cookie = vx_strdup(nextId.c_str());

    int request_count;
    int error = vx_issue_request3(req, &request_count);
    if (error)
    {
        KYBER_LOG(Error, "vx_issue_request3() returned error " << vx_get_error_string(error) << "(" << error << ") for request "
                                                               << vx_get_request_type_string(req->type));
        return;
    }
}

void VoipManager::Connect(char* loginAccessToken)
{
    vx_req_connector_create_t* req;
    vx_req_connector_create_create(&req);
    req->connector_handle = vx_strdup("c1");
    req->acct_mgmt_server = vx_strdup((std::string("https://unity.vivox.com/appconfig/") + m_issuer.c_str()).c_str());
    req->base.vcookie = loginAccessToken;
    SendRequest(&req->base);
}

void VoipManager::Login(char* loginAccessToken)
{
    vx_req_account_anonymous_login_t* req;
    vx_req_account_anonymous_login_create(&req);
    req->connector_handle = vx_strdup(m_connectorHandle.c_str());
    req->acct_name = vx_strdup(m_username.c_str());
    req->displayname = vx_strdup(m_displayName.c_str());
    req->account_handle = vx_strdup("");
    req->access_token = vx_strdup(loginAccessToken);
    req->enable_buddies_and_presence = 0;
    SendRequest(&req->base);
}

void VoipManager::AuxGetCaptureDevices()
{
    vx_req_aux_get_capture_devices_t* req;
    vx_req_aux_get_capture_devices_create(&req);
    req->account_handle = vx_strdup(m_accountHandle.c_str());
    SendRequest(&req->base);
}

void VoipManager::AuxGetRenderDevices()
{
    vx_req_aux_get_render_devices_t* req;
    vx_req_aux_get_render_devices_create(&req);
    req->account_handle = vx_strdup(m_accountHandle.c_str());
    SendRequest(&req->base);
}

void VoipManager::AddSession(const std::string& channel, const std::string& accessToken)
{
    if (!m_isEnabled)
    {
        return;
    }

    KYBER_LOG(Debug, "[VoIP] Joining channel " << channel);

    m_currentChannel = channel;

    vx_req_sessiongroup_add_session_t* req;
    vx_req_sessiongroup_add_session_create(&req);
    req->sessiongroup_handle = vx_strdup(("sg_" + channel).c_str());
    req->session_handle = vx_strdup(channel.c_str());
    req->uri = vx_strdup(channel.c_str());
    req->account_handle = vx_strdup(m_accountHandle.c_str());
    req->connect_audio = 1;
    req->connect_text = 0;
    req->access_token = vx_strdup(accessToken.c_str());
    SendRequest(&req->base);
}

void VoipManager::RemoveSession()
{
    if (m_currentChannel.empty())
    {
        return;
    }

    KYBER_LOG(Info, "Leaving channel " << m_currentChannel);

    vx_req_sessiongroup_remove_session_t* req;
    vx_req_sessiongroup_remove_session_create(&req);
    req->sessiongroup_handle = vx_strdup(("sg_" + m_currentChannel).c_str());
    req->session_handle = vx_strdup(m_currentChannel.c_str());
    SendRequest(&req->base);

    m_currentChannel.clear();
}

bool VoipManager::IsLoggedIn() const
{
    return m_isPostLogin;
}

bool VoipManager::IsConnected() const
{
    return !m_currentChannel.empty();
}

void VoipManager::SetCaptureDevice(const std::string& identifier)
{
    vx_req_aux_set_capture_device_t* req;
    vx_req_aux_set_capture_device_create(&req);
    req->account_handle = vx_strdup(m_accountHandle.c_str());
    req->capture_device_specifier = vx_strdup(identifier.c_str());
    SendRequest(&req->base);
}

void VoipManager::SetRenderDevice(const std::string& identifier)
{
    vx_req_aux_set_render_device_t* req;
    vx_req_aux_set_render_device_create(&req);
    req->account_handle = vx_strdup(m_accountHandle.c_str());
    req->render_device_specifier = vx_strdup(identifier.c_str());
    SendRequest(&req->base);
}

void VoipManager::SetMuted(bool muted)
{
    vx_req_connector_mute_local_mic_t* req;
    vx_req_connector_mute_local_mic_create(&req);
    req->mute_level = muted ? 1 : 0;
    req->account_handle = vx_strdup(m_accountHandle.c_str());
    SendRequest(&req->base);
}

void VoipManager::SetPushToTalkEnabled(bool enabled)
{
    m_pushToTalkEnabled = enabled;
    SetMuted(enabled);
}

void VoipManager::SetPushToTalkPressed(bool pressed)
{
    if (!m_pushToTalkEnabled)
    {
        return;
    } 
    
    if (m_isPushToTalkPressed == pressed)
    {
        return; // no need to send the request every time
    }

    KYBER_LOG(Debug, "[VoIP] Push-to-talk " << (pressed ? "PRESSED" : "RELEASED"));

    m_isPushToTalkPressed = pressed;
    SetMuted(!pressed);
}

void VoipManager::SetPushToTalkKey(uint32_t key)
{
    KYBER_LOG(Debug, "Setting PTT key to: " << key);
    m_pushToTalkKey = key;
}

void VoipManager::SetInputVolume(float volume)
{
    vx_req_aux_set_mic_level_t* req;
    vx_req_aux_set_mic_level_create(&req);
    req->level = volume;
    req->account_handle = vx_strdup(m_accountHandle.c_str());
    SendRequest(&req->base);
}

void VoipManager::SetSpeakerVolume(float volume)
{
    vx_req_aux_set_speaker_level_t* req;
    vx_req_aux_set_speaker_level_create(&req);
    req->level = volume;
    req->account_handle = vx_strdup(m_accountHandle.c_str());
    SendRequest(&req->base);
}

void VoipManager::SetEnabled(bool enabled)
{
    m_isEnabled = enabled;
}
} // namespace Kyber
