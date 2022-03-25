// Copyright BattleDash. All Rights Reserved.

#include <Utilities/ErrorUtils.h>

#include <string>

namespace Kyber
{
void ErrorUtils::ThrowException(LPCSTR message)
{
    LPCSTR base = "Something went wrong with Kyber. Please restart your game and report this to Kyber Staff if it "
                  "continues.\n\nException Details:\n";
    std::string combined = std::string(base) + message;
    LPCSTR combinedLPC = combined.c_str();

    MessageBox(0, combinedLPC, "Error", MB_ICONERROR);
    ExitProcess(EXIT_FAILURE);
}

void ErrorUtils::CloseGame(LPCSTR message)
{
    MessageBox(0, message, "Kyber", MB_ICONERROR);
    ExitProcess(EXIT_FAILURE);
}
} // namespace Kyber