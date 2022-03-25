// Copyright BattleDash. All Rights Reserved.

#include <Utilities/PlatformUtils.h>

#include <codecvt>
#include <filesystem>
#include <fstream>
#include <streambuf>
#include <string>

#define OFFSET_EXECUTIONCONTEXT_GETNATIVEDATAPATH 0x1401FDEC0

namespace Kyber
{
std::string PlatformUtils::GetGameDataPath()
{
    return std::string(((char* (*)(void))OFFSET_EXECUTIONCONTEXT_GETNATIVEDATAPATH)());
}

std::string PlatformUtils::GetFrostyMods()
{
    std::string dataDir = PlatformUtils::GetGameDataPath();
    std::ifstream in(std::filesystem::path(dataDir).append("patch").append("mods.txt"));
    std::string frostyMods = std::string((std::istreambuf_iterator<char>(in)), std::istreambuf_iterator<char>());
    std::replace(frostyMods.begin(), frostyMods.end(), '|', '\\');
    return frostyMods;
}

std::wstring PlatformUtils::utf8ToUtf16(const std::string& utf8Str)
{
    std::wstring_convert<std::codecvt_utf8_utf16<wchar_t>> conv;
    return conv.from_bytes(utf8Str);
}

std::string PlatformUtils::utf16ToUtf8(const std::wstring& utf16Str)
{
    std::wstring_convert<std::codecvt_utf8_utf16<wchar_t>> conv;
    return conv.to_bytes(utf16Str);
}

BOOL PlatformUtils::MaskCompare(PVOID pBuffer, LPCSTR lpPattern, LPCSTR lpMask)
{
    for (auto value = static_cast<PBYTE>(pBuffer); *lpMask; ++lpPattern, ++lpMask, ++value)
    {
        if (*lpMask == 'x' && *reinterpret_cast<LPCBYTE>(lpPattern) != *value)
            return false;
    }

    return true;
}

uintptr_t PlatformUtils::BaseAddress()
{
    return reinterpret_cast<uintptr_t>(GetModuleHandle(0));
}

PBYTE PlatformUtils::FindPattern(const char* pattern, const char* mask, int patternIndex)
{
    MODULEINFO mInfo = { 0 };

    GetModuleInformation(GetCurrentProcess(), GetModuleHandle(0), &mInfo, sizeof(mInfo));

    PVOID base = mInfo.lpBaseOfDll;
    DWORD64 size = (DWORD64)mInfo.SizeOfImage;

    DWORD64 patternLength = (DWORD64)strlen(mask);

    int patternI = 0;

    for (DWORD64 i = 0; i < size - patternLength; i++)
    {
        bool found = true;
        for (DWORD64 j = 0; j < patternLength; j++)
        {
            found &= mask[j] == '?' || pattern[j] == *(char*)(static_cast<PBYTE>(base) + i + j);
        }

        if (found)
        {
            if (patternI == patternIndex)
            {
                return static_cast<PBYTE>(base) + i;
            }
            patternI++;
        }
    }
    return NULL;
}

PBYTE PlatformUtils::FindPattern(PVOID pBase, DWORD dwSize, LPCSTR lpPattern, LPCSTR lpMask)
{
    dwSize -= static_cast<DWORD>(strlen(lpMask));

    for (auto i = 0UL; i < dwSize; ++i)
    {
        auto pAddress = static_cast<PBYTE>(pBase) + i;

        if (PlatformUtils::MaskCompare(pAddress, lpPattern, lpMask))
            return pAddress;
    }

    return NULL;
}

PBYTE PlatformUtils::FindPattern(LPCSTR lpPattern, LPCSTR lpMask, LPCWSTR lpModuleName)
{
    MODULEINFO info = { 0 };

    GetModuleInformation(GetCurrentProcess(), GetModuleHandleW(lpModuleName), &info, sizeof(info));

    return PlatformUtils::FindPattern(info.lpBaseOfDll, info.SizeOfImage, lpPattern, lpMask);
}

PBYTE PlatformUtils::FindPattern(LPCSTR lpPattern, LPCSTR lpMask)
{
    return PlatformUtils::FindPattern(lpPattern, lpMask, 0);
}
} // namespace Kyber