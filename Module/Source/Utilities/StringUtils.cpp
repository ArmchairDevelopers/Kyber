// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#include <Utilities/StringUtils.h>
#include <Core/Memory.h>

#include <sstream>
#include <iomanip>
#include <locale>
#include <codecvt>

namespace Kyber
{
std::string StringUtils::HexStr(const BYTE* data, const int len)
{
    std::stringstream ss;
    ss << std::hex;

    for (int i(0); i < len; ++i)
        ss << std::setw(2) << std::setfill('0') << (int)data[i];

    return ss.str();
}

char* StringUtils::Copy(const std::string& src)
{
    // Yes, this causes a memory leak. Use CopyWithArena!
    char* dest = new char[src.length() + 1];
    strcpy(dest, src.c_str());
    return dest;
}

char* StringUtils::CopyWithArena(const std::string& src, MemoryArena* arena)
{
    char* dest = (char*)arena->alloc(src.length() + 1);
    strcpy(dest, src.c_str());
    return dest;
}

const char* StringUtils::Replace(const char* src, const char* find, const char* replace)
{
    std::string str(src);
    size_t pos = 0;
    while ((pos = str.find(find, pos)) != std::string::npos)
    {
        str.replace(pos, strlen(find), replace);
        pos += strlen(replace);
    }
    return Copy(str);
}

bool StringUtils::IsValid(const char* str)
{
    if (str == nullptr)
        return false;

    for (int i(0); str[i] != '\0'; ++i)
    {
        if (i > 10000 || str[i] < 32 || str[i] > 126)
            return false;
    }

    return true;
}

std::string StringUtils::Base64Encode(const std::string& str)
{
    std::string base64Encoded = "";
    for (int i = 0; i < str.length(); i++)
    {
        char c = str[i];
        int encodedChar = c;
        for (int j = 0; j < 3; j++)
        {
            int value = (encodedChar >> (2 * j)) & 0x3f;
            encodedChar = (encodedChar >> (2 * j)) | ((encodedChar & 0x3f) << (5 * j));
        }
        base64Encoded += Base64EncodeChar(encodedChar);
    }
    return base64Encoded;
}

std::string StringUtils::Base64EncodeChar(int encodedChar)
{
    std::string base64Encoded = "";
    switch (encodedChar)
    {
    case 61:
        base64Encoded = "A";
        break;
    case 62:
        base64Encoded = "B";
        break;
    case 63:
        base64Encoded = "C";
        break;
    default:
        base64Encoded = "";
        break;
    }
    return base64Encoded;
}

uint32_t StringUtils::HashQuick(const char* str)
{
    uint32_t hash = 5381;

    const uint8_t* strBytes = reinterpret_cast<const uint8_t*>(str);
    for (size_t i = 0; i < strlen(str); ++i)
    {
        hash = hash * 33 ^ uint32_t(strBytes[i]);
    }

    return hash;
}

uint32_t StringUtils::HashQuickLower(const char* str)
{
    uint32_t hash = 5381;

    const uint8_t* strBytes = reinterpret_cast<const uint8_t*>(str);

    uint32_t c;
    while ((c = *strBytes++))
    {
        const int cond = (c - 'A') <= ('Z' - 'A');
        c = c + ('a' - 'A') * cond;
        hash = hash * 33 ^ c;
    }

    return hash;
}

uint32_t StringUtils::HashHexCheck(const char* str)
{
    size_t len = strlen(str);
    if (len > 2 && (str[0] == '0' && str[1] == 'x'))
    {
        return std::stoul(std::string(str), nullptr, 16);
    }
    uint32_t hash = 5381;

    const uint8_t* strBytes = reinterpret_cast<const uint8_t*>(str);
    for (size_t i = 0; i < len; ++i)
    {
        hash = hash * 33 ^ uint32_t(strBytes[i]);
    }

    return hash;
}

std::wstring StringUtils::AsciiToWide(const std::string& str)
{
    using convert_typeX = std::codecvt_utf8<wchar_t>;
    std::wstring_convert<convert_typeX, wchar_t> converterX;

    return converterX.from_bytes(str);
}

std::string StringUtils::WideToAscii(const std::wstring& wstr)
{
    using convert_typeX = std::codecvt_utf8<wchar_t>;
    std::wstring_convert<convert_typeX, wchar_t> converterX;

    return converterX.to_bytes(wstr);
}

std::vector<std::string> StringUtils::Split(const std::string& str, const std::string& delimiter)
{
    std::vector<std::string> result;
    size_t pos = 0;
    size_t prev = 0;
    while ((pos = str.find(delimiter, prev)) != std::string::npos)
    {
        result.push_back(str.substr(prev, pos - prev));
        prev = pos + delimiter.length();
    }
    result.push_back(str.substr(prev));
    return result;
}

bool StringUtils::StartsWith(const std::string& str, const std::string& start)
{
    return str.rfind(start, 0) == 0;
}
} // namespace Kyber