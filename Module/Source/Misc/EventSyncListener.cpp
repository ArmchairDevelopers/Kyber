// Copyright Armchair Developers. Licensed under GPLv3. 

#include <Misc/EventSyncListener.h>

#include <Base/Log.h>
#include <Hook/HookManager.h>
#include <SDK/TypeInfo.h>
#include <SDK/SDK.h>
#include <SDK/Funcs.h>

#include <EASTL/map.h>

#define OFFSET_SERVEREVENTSYNCENTITY_MESSAGE HOOK_OFFSET(0x140C5E3D0)

namespace Kyber
{
TL_DECLARE_FUNC(0x140D7AC00, void*, GetGhost, void*);

static std::vector<std::pair<std::string, std::string>> s_eventSyncBlacklist = {
    // All SubWorldData EventSyncs
    {"Levels/MP/",                                      "*"},
    {"Levels/Space/",                                   "*"},
    {"S1/Levels/",                                      "*"},
    {"S2/Levels/",                                      "*"},
    {"S2_1/Levels/",                                    "*"},
    {"S2_2/Levels/",                                    "*"},
    {"S3/Levels/",                                      "*"},
    {"S5_1/Levels/",                                    "*"},
    {"S6_2/Geonosis_02/",                               "*"},
    {"S7/Levels/",                                      "*"},
    {"S7_1/Levels/",                                    "*"},
    {"S7_2/Levels/",                                    "*"},
    {"S8/Felucia/",                                     "*"},
    {"S8_1/Endor_04/",                                  "*"},
    {"S9/Jakku_02/",                                    "*"},
    {"S9/Paintball/",                                   "*"},
    {"S9/Starkiller_02/",                               "*"},
    {"S9/Takodana_02/",                                 "*"},
    {"S9_3/COOP_NT_FOSD/",                              "*"},
    {"S9_3/COOP_NT_MC85/",                              "*"},
    {"S9_3/Crait/",                                     "*"},
    {"S9_3/Hoth_02/",                                   "*"},
    {"S9_3/Scarif/",                                    "*"},
    {"S9_3/Tatooine_02/",                               "*"},

    // Automation
    {"Automation/",                                     "*"},
    {"S1/Automation/",                                  "*"},

    // Gameplay Blueprints
    {"Gameplay/GameModes/Mode8/Prefabs/",        "62245106"},
    {"Gameplay/GameModes/Skirmish/",             "64259748"},
    {"Gameplay/GameModes/Skirmish/",             "44404859"},
    {"UI/InGame/InGameMenu/",                           "*"}
};

void UpdateBlacklist()
{
    auto updatedBlacklistOpt = g_program->GetAPI()->GetClientServer()->GetBlacklist();
    if (!updatedBlacklistOpt.has_value())
    {
        KYBER_LOG(Error, "[EventSync] Failed to retrieve blacklist");
        return;
    }

    s_eventSyncBlacklist.clear();
    const auto& blacklist = updatedBlacklistOpt.value();
    s_eventSyncBlacklist.reserve(blacklist.size());
    
    for (const auto& entry : blacklist)
    {
        size_t colonPos = entry.find_last_of(':');
        if (colonPos != std::string::npos)
        {
            std::string path = entry.substr(0, colonPos);
            std::string pattern = entry.substr(colonPos + 1);
            s_eventSyncBlacklist.emplace_back(path, pattern);
        }
        else
        {
            s_eventSyncBlacklist.emplace_back(entry, "");
        }
    }
    
    KYBER_LOG(Info, "[EventSync] Updated EventSync blacklist with " << s_eventSyncBlacklist.size() << " entries");
}

static bool IsEventSyncBlacklisted(const char* path, uint32_t flags)
{
    if (path == nullptr)
    {
        return false;
    }

    for (const auto& [prefix, rule] : s_eventSyncBlacklist)
    {
        if (prefix.c_str() == nullptr)
        {
            continue;
        }

        if (strstr(path, prefix.c_str()) != path)
        {
            continue;
        }

        if (rule[0] == '*')
        {
            return true;
        }

        return flags == std::stoi(rule);
    }

    return false;
}

struct EventSyncListenerIds
{
    uintptr_t owner;
    uint32_t bus;
    uint32_t data;

    bool operator<(const EventSyncListenerIds& listener) const
    {
        if (owner != listener.owner)
        {
            return owner < listener.owner;
        }
        if (bus != listener.bus)
        {
            return bus < listener.bus;
        }
        else
        {
            return data < listener.data;
        }
    }
};

void ServerEventSyncOnMessageHk(uintptr_t inst, EventSyncReachedClientMessage* msg)
{
    static const auto trampoline = HookManager::Call(ServerEventSyncOnMessageHk);

    if (!msg->Is("EventSyncReachedClientMessage"))
    {
        KYBER_LOG(Debug, "[EventSync] Got message of type " << msg->getType()->getName() << " instead!");
        return trampoline(inst, msg);
    }

    void* ghost = GetGhost(&msg->ghostPtr);
    if (ghost == nullptr)
    {
        KYBER_LOG(Debug, "[EventSync] Null Ghost!");
        return trampoline(inst, msg);
    }

    EventSyncListenerIds listenerIds;
    listenerIds.owner = { ~0u };
    listenerIds.data = msg->data;
    listenerIds.bus = msg->bus;
    
    // It does this in the exe for some reason so whatever
    void* ghost2 = GetGhost(&msg->ghostPtr);
    if (ghost2 == nullptr)
    {
        KYBER_LOG(Debug, "[EventSync] No Ghost 2!");
        return trampoline(inst, msg);
    }
    listenerIds.owner = uintptr_t(ghost2);

    typedef eastl::map<EventSyncListenerIds, NativeEntity*> EntityMap;
    EntityMap& entities = *reinterpret_cast<EntityMap*>(inst + 0x10);

    EntityMap::const_iterator it = entities.find(listenerIds);
    if (it == entities.end())
    {
        KYBER_LOG(Debug, "[EventSync] No Entity Found");
        return trampoline(inst, msg);
    }

    if (!msg->serverConnection->ValidateLocalPlayer(msg->localPlayerId, false))
    {
        KYBER_LOG(Debug, "[EventSync] Couldn't validate LocalPlayer!");
        return trampoline(inst, msg);
    }

    ServerPlayer* player = msg->serverConnection->GetPlayer(msg->localPlayerId, true);
    if (player == nullptr)
    {
        KYBER_LOG(Warning, "[EventSync] Couldn't validate LocalPlayer!");
        return trampoline(inst, msg);
    }

    NativeEntity* entity = it->second;
    if (entity == nullptr)
    {
        KYBER_LOG(Debug, "[EventSync] No NativeEntity found");
        return trampoline(inst, msg);
    }

    Blueprint* blueprint = reinterpret_cast<Blueprint*>(entity->GetEntityBus()->GetExposedPeerData());
    if (blueprint == nullptr)
    {
        KYBER_LOG(Debug, "[EventSync] No Blueprint found");
        return trampoline(inst, msg);
    }

    char* blueprintName = blueprint->Name;
    if (blueprintName == nullptr)
    {
        KYBER_LOG(Debug, "[EventSync] No Blueprint Name found");
        return trampoline(inst, msg);
    }

    uint32_t flags = entity->GetData()->Flags;

    if (!IsEventSyncBlacklisted(blueprintName, flags))
    {
        return trampoline(inst, msg);
    }

    // From here on, no trampoline, as we want to block the EventSync

    if (std::getenv("KYBER_EVENT_SYNC_LOGGING") != nullptr)
    {
        // Only prints a warning if from files containing "Automation" or "Game" as they have the bigger exploits
        if (strstr(blueprintName, "Automation") != nullptr || strstr(blueprintName, "Game") != nullptr)
        {
            KYBER_LOG(Warning, "[EventSync] Blocked EventSync " << blueprintName << ":" << flags << " was activated by " << player->m_name
                                                                << " (" << player->m_onlineId.m_nativeData << ")");
        }
        else
        {
            KYBER_LOG(Debug, "[EventSync] Blocked EventSync " << blueprintName << ":" << flags << " was activated by " << player->m_name
                                                              << " (" << player->m_onlineId.m_nativeData << ")");
        }
    }
}

void InitializeEventSyncHook()
{
    UpdateBlacklist();

    HookManager::CreateHook(OFFSET_SERVEREVENTSYNCENTITY_MESSAGE, ServerEventSyncOnMessageHk);
}
} // namespace Kyber