#pragma once

// See https://0xrick.github.io/win-internals/pe8/

#include <filesystem>

#include <Windows.h>
#include <winnt.h>
#include <stdint.h>

enum class PEResult : uint32_t
{
    Success = 0,
    
    ErrorReadFileOpen = 1,
    ErrorReadFileAlloc = 2,
    ErrorReadFileData = 3,

    ErrorInvalidFileSignature = 10,
    ErrorInvalidFileTooManySections = 11,

    ErrorReadImportsTableOffset = 20,

    ErrorAddSectionMaxReached = 30,

    ErrorSaveFileCreate = 40

};

// Could be in theory 65535, on XP only 96 (see https://stackoverflow.com/questions/17466916/whats-the-maximum-number-of-sections-a-pe-can-have) 
constexpr auto MAX_SECTIONS = 64;
constexpr auto IMPORT_SECTION_NAME = "@.import";
constexpr auto RESERV_SECTION_NAME = "@.reserv";

struct PE_DOS_STUB
{
    int8_t* RawData;
    DWORD Size;
};

struct PE_IMPORT_FUNCTION_ENTRY
{
    char* Name;
    int Id;
    PE_IMPORT_FUNCTION_ENTRY* Next;
};

struct PE_IMPORT_DLL_ENTRY
{
    char* Name;
    PE_IMPORT_FUNCTION_ENTRY* Functions;
    PE_IMPORT_DLL_ENTRY* Next;
};

struct PE_SECTION_ENTRY
{
    DWORD Offset;
    int8_t* RawData;
    DWORD Size;
};


class PEFile
{
public:
    PEFile();
    ~PEFile();
private:
    void Initialize();
public:
    void UnloadFile();
    PEResult LoadFromFile(std::filesystem::path filePath);
    PEResult LoadFromMemory(void* memoryAddress);
    PEResult SaveToFile(std::filesystem::path filePath);

    int32_t AddSection(std::string_view name, DWORD size, bool isExecutable);
    void AddImport(std::string_view dllName, char** functions, int functionCount);
    void Commit();

private:
    IMAGE_DOS_HEADER m_dosHeader;
    PE_DOS_STUB m_dosStub;
    IMAGE_NT_HEADERS m_ntHeaders;
    IMAGE_SECTION_HEADER m_sectionTable[MAX_SECTIONS];
    PE_SECTION_ENTRY m_reservedData;
    PE_SECTION_ENTRY m_sections[MAX_SECTIONS];
    PE_IMPORT_DLL_ENTRY m_importTable;
    PE_IMPORT_DLL_ENTRY m_additionalImports;

    int8_t* m_loadedPeFile;

    PEResult ReadFile(std::filesystem::path filePath);
    PEResult IsValid();
    PEResult ReadAll();
    PEResult ReadHeaders();
    void ReadSections();
    PEResult ReadImports();


    void RebuildImportTable();
    char* BuildAdditionalImports(DWORD baseRVA);
    DWORD CalculateAdditionalImportsSize(DWORD& sizeDlls, DWORD& sizeFunctions, DWORD& sizeStrings);

    bool WritePadding(std::ofstream& file, long paddingSize);
    DWORD AlignNumber(DWORD number, DWORD alignment);
    DWORD RvaToOffset(DWORD rva);
    DWORD OffsetToRVA(DWORD offset);

    void ComputeReservedData();
    void ComputeHeaders();
    void ComputeSectionTable();
};