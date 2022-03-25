#include <Windows.h>
#include <psapi.h>
#include <string>

namespace Kyber
{
class PlatformUtils
{
public:
    static std::string GetGameDataPath();
    static std::string GetFrostyMods();
    static std::wstring utf8ToUtf16(const std::string& utf8Str);
    static std::string utf16ToUtf8(const std::wstring& utf16Str);
    static uintptr_t BaseAddress();
    static PBYTE FindPattern(const char* pattern, const char* mask, int patternIndex);
    static PBYTE FindPattern(PVOID pBase, DWORD dwSize, LPCSTR lpPattern, LPCSTR lpMask);
    static PBYTE FindPattern(LPCSTR lpPattern, LPCSTR lpMask);
    static PBYTE FindPattern(LPCSTR lpPattern, LPCSTR lpMask, LPCWSTR lpModuleName);

private:
    static BOOL MaskCompare(PVOID pBuffer, LPCSTR lpPattern, LPCSTR lpMask);
};
} // namespace Kyber