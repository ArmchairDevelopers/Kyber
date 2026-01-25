// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#pragma once

#include <Script/LuaEventManager.h>

#include <filesystem>
#include <optional>

#include <zip.h>

namespace Kyber
{
struct PluginManifest
{
    std::string name;

    PluginManifest() = default;
    PluginManifest(std::string source);
};

enum PluginRealm
{
    PluginRealm_Client = 0,
    PluginRealm_Server = 1,
    PluginRealm_Count
};

class PluginBase
{
    friend class ScriptManager;

public:
    PluginBase(PluginRealm realm);
    virtual ~PluginBase() = default;

    virtual std::optional<std::string> LoadFile(const std::string& path) = 0;

    const PluginManifest& GetManifest() const
    {
        return m_manifest;
    }

    PluginRealm GetRealm() const
    {
        return m_realm;
    }

    std::string LogPrefix() const
    {
        return "[" + m_manifest.name + "]";
    }

protected:
    void SetManifest(PluginManifest manifest);

private:
    PluginManifest m_manifest;
    lua_State* m_lua;

    PluginRealm m_realm;
};

class LocalPlugin : public PluginBase
{
public:
    LocalPlugin(PluginRealm realm, std::filesystem::path path);

    std::optional<std::string> LoadFile(const std::string& path) override;

private:
    std::filesystem::path m_basePath;
};

class PackagedPlugin : public PluginBase
{
public:
    PackagedPlugin(PluginRealm realm, std::filesystem::path path);
    ~PackagedPlugin();

    std::optional<std::string> LoadFile(const std::string& path) override;

private:
    zip_t* m_zip;
};

class ScriptManager
{
public:
    ScriptManager();
    ~ScriptManager();

    void LoadScripts(PluginRealm realm);
    void LoadPlugin(PluginBase* plugin);

    void LoadLocalPlugin(PluginRealm realm, std::filesystem::path path);
    void LoadPackagedPlugin(PluginRealm realm, std::filesystem::path path);

    void Reset();

    LuaEventManager& GetEventManager()
    {
        return m_eventManager;
    }

    bool IsPostInitialization(PluginRealm realm)
    {
        return m_blockPostInit[realm];
    }

    static void StorePlugin(lua_State* L, PluginBase* plugin);
    static PluginBase* GetPlugin(lua_State* L);

private:
    void LoadPluginsFromDirectory(PluginRealm realm, const std::filesystem::path& path);

    LuaEventManager m_eventManager;
    // This system is awful disgusting and killed my hb, probably will change later
    bool m_blockPostInit[PluginRealm_Count];
};
} // namespace Kyber