#include <iostream>

#include "PEFile.h"

int WaitForExit(PEResult rc, const char* msg)
{
    if (rc != PEResult::Success)
        std::cout << msg << (int)rc << std::endl;
    else
        std::cout << msg << std::endl;

    std::cout << "Press ENTER to exit.." << std::endl;
    std::cin.ignore();
    std::cin.get();

    return (int)rc;
}


int WINAPI wWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, PWSTR pCmdLine, int nCmdShow)
//int main(int argc, char* argv[])
{
    // Open the input file
    PEFile pe;

    PEResult rc = pe.LoadFromFile("dinput8.dll");
    if (rc != PEResult::Success)
    {
        return WaitForExit(rc, "Failed to load file: ");
    }
    std::cout << "Loaded PE file" << std::endl;

    // Add the exported functions of your DLL
    const char* functions[] = { "SomeFunction" };

    // Add the import to the PE file
    pe.AddImport("Kyber.dll", (char**)functions, 1);
    std::cout << "Added imports to PE file" << std::endl;

    // Save the modified file
    rc = pe.SaveToFile("dinput8.dll");
    if (rc != PEResult::Success)
    {
        return WaitForExit(rc, "Failed to save file: ");
    }

    return WaitForExit(PEResult::Success, "Saved modified PE file");
}