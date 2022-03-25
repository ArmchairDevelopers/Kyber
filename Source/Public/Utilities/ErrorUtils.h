// Copyright BattleDash. All Rights Reserved.

#pragma once

#include <Windows.h>

namespace Kyber
{
class ErrorUtils
{
public:
    static void ThrowException(LPCSTR message);
    static void CloseGame(LPCSTR message);
};
} // namespace Kyber