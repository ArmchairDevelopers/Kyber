// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#include <Script/ScriptManager.h>
#include <Core/Program.h>
#include <Utilities/PlatformUtils.h>
#include <Script/Lua.h>
#include <Script/LuaDataContainer.h>
#include <Script/LuaConsole.h>
#include <Script/LuaGlobals.h>
#include <Script/LuaPlayerManager.h>
#include <Script/LuaSocketManager.h>
#include <Script/LuaEntityManager.h>
#include <Script/LuaResourceManager.h>
#include <Script/LuaUtilFunctions.h>
#include <Script/LuaClientEvents.h>

namespace Kyber
{
PluginManifest::PluginManifest(std::string source)
{
    auto json = nlohmann::json::parse(source);
    name = json["name"].get<std::string>();
}

PluginBase::PluginBase(PluginRealm realm)
    : m_lua(nullptr)
    , m_realm(realm)
{}

void PluginBase::SetManifest(PluginManifest manifest)
{
    m_manifest = manifest;
}

LocalPlugin::LocalPlugin(PluginRealm realm, std::filesystem::path path)
    : PluginBase(realm)
    , m_basePath(path)
{
    std::optional<std::string> manifest = LocalPlugin::LoadFile("plugin.json");
    if (!manifest)
    {
        KYBER_LOG(Error, "Failed to load plugin '" << path.string().c_str() << "', no plugin.json file");
        return;
    }

    SetManifest(PluginManifest(*manifest));
}

std::optional<std::string> LocalPlugin::LoadFile(const std::string& path)
{
    auto fullPath = m_basePath / std::filesystem::path(path);
    if (!exists(fullPath))
    {
        return std::nullopt;
    }

    std::ifstream stream(fullPath);
    std::stringstream buffer;
    buffer << stream.rdbuf();
    return buffer.str();
}

PackagedPlugin::PackagedPlugin(PluginRealm realm, std::filesystem::path path)
    : PluginBase(realm)
{
    int ziperr = 0;
    m_zip = zip_openwitherror(path.string().c_str(), 0, 'r', &ziperr);
    if (m_zip == nullptr)
    {
        KYBER_LOG(Error, "Failed to open plugin '" << path.string().c_str() << "', error: " << zip_strerror(ziperr));
        return;
    }

    std::optional<std::string> manifest = PackagedPlugin::LoadFile("plugin.json");
    if (!manifest)
    {
        KYBER_LOG(Error, "Failed to load plugin '" << path.string().c_str() << "', no plugin.json file");
        return;
    }

    SetManifest(PluginManifest(*manifest));
}

PackagedPlugin::~PackagedPlugin()
{
    if (m_zip != nullptr)
    {
        zip_close(m_zip);
    }
}

std::optional<std::string> PackagedPlugin::LoadFile(const std::string& path)
{
    char* buf = nullptr;
    size_t len = 0;

    int err = zip_entry_open(m_zip, path.c_str());
    if (err < 0)
    {
        return std::nullopt;
    }

    ssize_t ret = zip_entry_read(m_zip, (void**)&buf, &len);
    if (ret < 0)
    {
        KYBER_LOG(Error, LogPrefix() << " Failed to read file '" << path << "': " << zip_strerror(ret));
        return std::nullopt;
    }

    err = zip_entry_close(m_zip);
    if (err < 0)
    {
        KYBER_LOG(Error, LogPrefix() << " Failed to close file '" << path << "': " << zip_strerror(err));
    }

    std::string result(buf, len);
    free(buf);

    return result;
}

ScriptManager::ScriptManager()
{
    KYBER_LOG(Info, "[Plugin] Initializing script manager with " << LUA_RELEASE);

    LuaPlayerManager::InitializeHooks();
}

void ScriptManager::LoadPluginsFromDirectory(PluginRealm realm, const std::filesystem::path& path)
{
    for (const auto& entry : std::filesystem::directory_iterator(path))
    {
        if (entry.path().extension() == ".kbplugin")
        {
            LoadPackagedPlugin(realm, entry.path());
        }
        else
        {
            KYBER_LOG(Warning, "Skipping non-plugin file: " << entry.path().string());
        }
    }
}

void ScriptManager::LoadScripts(PluginRealm realm)
{
    const char* pluginPath = std::getenv("KYBER_DEV_PLUGIN_PATH");

    if (realm == PluginRealm_Server && pluginPath != nullptr)
    {
        if (strstr(pluginPath, ".zip") != nullptr || 
            strstr(pluginPath, ".kbplugin") != nullptr)
        {
            LoadPackagedPlugin(PluginRealm_Server, pluginPath);
        }
        else
        {
            LoadLocalPlugin(PluginRealm_Server, pluginPath);
        }
    }

    if (realm == PluginRealm_Server)
    {
        const char* pluginsPath = std::getenv("KYBER_SERVER_PLUGINS_PATH");
        if (pluginsPath != nullptr)
        {
            LoadPluginsFromDirectory(realm, pluginsPath);
        }
        m_blockPostInit[PluginRealm_Server] = true;
    }

    if (realm == PluginRealm_Client)
    {
        const char* pluginsPath = std::getenv("KYBER_CLIENT_PLUGINS_PATH");
        if (pluginsPath != nullptr)
        {
            KYBER_LOG(Error, "Kyber Client Plugins are now depreciated! Plugins will not be loaded.");
            //LoadPluginsFromDirectory(realm, pluginsPath);
        }
        m_blockPostInit[PluginRealm_Client] = true;
    }
}

void ScriptManager::LoadPlugin(PluginBase* script)
{
    KB_LUA_LOCK;

    lua_State* L = luaL_newstate();
    // Safe libraries (according to: https://github.com/kikito/lua-sandbox/blob/master/sandbox.lua#L59)
    luaL_openselectedlibs(L,
        LUA_GLIBK | LUA_LOADLIBK | LUA_COLIBK | LUA_MATHLIBK |
            LUA_OSLIBK | /* Some functions are safe, but best to remove the entire thing. */
            LUA_STRLIBK | LUA_TABLIBK,
        0);

    // Remove certain OS functions
    lua_getglobal(L, "os");
    lua_pushnil(L);
    lua_setfield(L, -2, "execute");
    lua_pushnil(L);
    lua_setfield(L, -2, "exit");
    lua_pushnil(L);
    lua_setfield(L, -2, "remove");
    lua_pushnil(L);
    lua_setfield(L, -2, "rename");
    lua_pushnil(L);
    lua_setfield(L, -2, "setlocale");
    lua_pushnil(L);
    lua_setfield(L, -2, "tmpname");
    lua_pop(L, 1);

    StorePlugin(L, script);

    LuaEventManager::Register(L);
    LuaDataContainer::Register(L);
    LuaEntityManager::Register(L);
    LuaPlayerManager::Register(L);
    LuaSocketManager::Register(L);

    Script::RegisterGlobals(L);
    Script::RegisterConsoleTable(L);
    Script::RegisterResourceManagerTable(L);
    Script::RegisterUtilTable(L);
    Script::RegisterClientEvents(L);

    KYBER_LOG(Info, script->LogPrefix() << " Initialized plugin");

    auto commonInit = script->LoadFile("common/__init__.lua");
    if (commonInit && luaL_dostring(L, commonInit->c_str()))
    {
        KYBER_LOG(Error, script->LogPrefix() << " Failed to load common init script: " << lua_tostring(L, -1));
        lua_pop(L, 1);
    }

    std::string realmPath;
    switch (script->GetRealm())
    {
    case PluginRealm_Client:
        realmPath = "client";
        break;
    case PluginRealm_Server:
        realmPath = "server";
        break;
    }

    auto realmInit = script->LoadFile(realmPath + "/__init__.lua");
    if (realmInit && luaL_dostring(L, realmInit->c_str()))
    {
        KYBER_LOG(Error, script->LogPrefix() << " Failed to load server init script: " << lua_tostring(L, -1));
        lua_pop(L, 1);
    }
}

void ScriptManager::LoadLocalPlugin(PluginRealm realm, std::filesystem::path path)
{
    LocalPlugin* script = new LocalPlugin(realm, path);
    LoadPlugin(script);
}

void ScriptManager::LoadPackagedPlugin(PluginRealm realm, std::filesystem::path path)
{
    PackagedPlugin* script = new PackagedPlugin(realm, path);
    LoadPlugin(script);
}

void ScriptManager::Reset()
{
    m_eventManager.Reset();
}

void ScriptManager::StorePlugin(lua_State* L, PluginBase* plugin)
{
    KB_LUA_LOCK;

    lua_newtable(L);
    lua_pushlightuserdata(L, plugin);
    lua_setfield(L, -2, "__plugin");
    lua_setglobal(L, "plugin");
}

PluginBase* ScriptManager::GetPlugin(lua_State* L)
{
    KB_LUA_LOCK;

    lua_getglobal(L, "plugin");
    lua_getfield(L, -1, "__plugin");
    PluginBase* plugin = static_cast<PluginBase*>(lua_touserdata(L, -1));
    lua_pop(L, 2);
    return plugin;
}
} // namespace Kyber
