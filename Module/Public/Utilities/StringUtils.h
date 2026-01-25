// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#pragma once

#include <Core/Memory.h>

#include <Windows.h>
#include <string>
#include <vector>

namespace Kyber
{
class StringUtils
{
public:
    static std::string HexStr(const BYTE* data, int len);
    static char* Copy(const std::string& src);
    static char* CopyWithArena(const std::string& src, MemoryArena* arena = FB_STATIC_ARENA);
    static const char* Replace(const char* src, const char* find, const char* replace);
    static bool IsValid(const char* str);
    static std::string Base64Encode(const std::string& str);
    static uint32_t HashQuick(const char* str);
    static uint32_t HashQuickLower(const char* str);
    static uint32_t HashHexCheck(const char* str);
    static std::wstring AsciiToWide(const std::string& str);
    static std::string WideToAscii(const std::wstring& wstr);
    static std::vector<std::string> Split(const std::string& str, const std::string& delimiter);
    static bool StartsWith(const std::string& str, const std::string& start);

    // https://stackoverflow.com/questions/2342162/stdstring-formatting-like-sprintf
    template<typename... Args>
    static std::string Format(const std::string& format, Args... args)
    {
        int size_s = std::snprintf(nullptr, 0, format.c_str(), args...) + 1; // Extra space for '\0'
        if (size_s <= 0)
        {
            throw std::runtime_error("Error during formatting.");
        }

        auto size = static_cast<size_t>(size_s);
        std::unique_ptr<char[]> buf(new char[size]);
        std::snprintf(buf.get(), size, format.c_str(), args...);
        return std::string(buf.get(), buf.get() + size - 1); // We don't want the '\0' inside
    }

private:
    static std::string Base64EncodeChar(int encoded_char);
};
} // namespace Kyber