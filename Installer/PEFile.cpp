#include "PEFile.h"

#include <math.h>
#include <fstream>


PEFile::PEFile()
{
    Initialize();
}

PEFile::~PEFile()
{
    UnloadFile();
}

void PEFile::Initialize()
{
    m_loadedPeFile = nullptr;
    memset(&m_additionalImports, 0, sizeof(PE_IMPORT_DLL_ENTRY));
}

void PEFile::UnloadFile()
{
    if (m_loadedPeFile != nullptr)
    {
        VirtualFree(m_loadedPeFile, 0, MEM_RELEASE);
        m_loadedPeFile = nullptr;
    }
}

PEResult PEFile::LoadFromFile(std::filesystem::path filePath) {
    UnloadFile();

    PEResult rc = ReadFile(filePath);
    if (rc != PEResult::Success)
        return rc;

    return ReadAll();
}

PEResult PEFile::LoadFromMemory(void* memoryAddress)
{
    UnloadFile();

    m_loadedPeFile = (int8_t*)memoryAddress;

    return ReadAll();
}

PEResult PEFile::SaveToFile(std::filesystem::path filePath)
{
    Commit();
    RebuildImportTable();

    std::ofstream file(filePath, std::ios::binary | std::ios::ate);
    if (!file)
    {
        return PEResult::ErrorSaveFileCreate;
    }

    file.write((char*)&m_dosHeader, sizeof(IMAGE_DOS_HEADER));
    file.write((char*)m_dosStub.RawData, m_dosStub.Size);
    WritePadding(file, m_dosHeader.e_lfanew - sizeof(IMAGE_DOS_HEADER) - m_dosStub.Size);
    file.write((char*)&m_ntHeaders, sizeof(IMAGE_NT_HEADERS));
    file.write((char*)&m_sectionTable, m_ntHeaders.FileHeader.NumberOfSections * sizeof(IMAGE_SECTION_HEADER));
    file.write((char*)m_reservedData.RawData, m_reservedData.Size);

    for (int i = 0; i < m_ntHeaders.FileHeader.NumberOfSections; i++)
    {
        WritePadding(file, m_sectionTable[i].PointerToRawData - file.tellp());
        file.write((char*)m_sections[i].RawData, m_sections[i].Size);
    }

    return PEResult::Success;
}

int32_t PEFile::AddSection(std::string_view name, DWORD size, bool isExecutable)
{
    // Return if max sections are reached
    if (m_ntHeaders.FileHeader.NumberOfSections == MAX_SECTIONS)
    {
        return -1;
    }

    PE_SECTION_ENTRY& newSection = m_sections[m_ntHeaders.FileHeader.NumberOfSections];
    IMAGE_SECTION_HEADER& newSectionHeader = m_sectionTable[m_ntHeaders.FileHeader.NumberOfSections];
    IMAGE_SECTION_HEADER& lastSectionHeader = m_sectionTable[m_ntHeaders.FileHeader.NumberOfSections - 1];

    DWORD sectionSize = AlignNumber(size, m_ntHeaders.OptionalHeader.FileAlignment);
    DWORD virtualSize = AlignNumber(sectionSize, m_ntHeaders.OptionalHeader.SectionAlignment);

    DWORD sectionOffset = AlignNumber(lastSectionHeader.PointerToRawData + lastSectionHeader.SizeOfRawData, m_ntHeaders.OptionalHeader.FileAlignment);
    DWORD virtualOffset = AlignNumber(lastSectionHeader.VirtualAddress + lastSectionHeader.Misc.VirtualSize, m_ntHeaders.OptionalHeader.SectionAlignment);

    memset(&newSectionHeader, 0, sizeof(IMAGE_SECTION_HEADER));
    memcpy(newSectionHeader.Name, name.data(), name.length() > 8 ? 8 : name.length());

    newSectionHeader.PointerToRawData = sectionOffset;
    newSectionHeader.VirtualAddress = virtualOffset;
    newSectionHeader.SizeOfRawData = sectionSize;
    newSectionHeader.Misc.VirtualSize = virtualSize;
    newSectionHeader.Characteristics = IMAGE_SCN_MEM_READ | IMAGE_SCN_MEM_WRITE | IMAGE_SCN_CNT_INITIALIZED_DATA;

    if (isExecutable)
    {
        newSectionHeader.Characteristics |= IMAGE_SCN_CNT_CODE | IMAGE_SCN_MEM_EXECUTE;
    }

    newSection.RawData = (int8_t*)GlobalAlloc(GMEM_FIXED | GMEM_ZEROINIT, sectionSize);
    newSection.Size = sectionSize;

    m_ntHeaders.FileHeader.NumberOfSections++;
    if (m_reservedData.Size > 0)
    {
        m_reservedData.Size -= sizeof(IMAGE_SECTION_HEADER);
    }

    // Return the new section index
    return m_ntHeaders.FileHeader.NumberOfSections - 1;
}

void PEFile::AddImport(std::string_view dllName, char** functions, int functionCount)
{
    PE_IMPORT_DLL_ENTRY* importDll = &this->m_additionalImports;
    PE_IMPORT_FUNCTION_ENTRY* importFunction;

    if (m_additionalImports.Name != nullptr)
    {
        while (importDll->Next != nullptr)
        {
            importDll = importDll->Next;
        }
        importDll->Next = new PE_IMPORT_DLL_ENTRY();
        importDll = importDll->Next;
    }
    // Copy dll name and alloc it on the heap
    size_t sizeOfName = dllName.length() + 1;
    char* allocedName = new char[sizeOfName];
    strcpy_s(allocedName, sizeOfName, dllName.data());
    //strcpy(allocedName, dllName.data());
    importDll->Name = allocedName;
    importDll->Functions = new PE_IMPORT_FUNCTION_ENTRY();
    importDll->Next = nullptr;

    importFunction = importDll->Functions;
    importFunction->Name = functions[0];
    for (int i = 1; i < functionCount; i++)
    {
        importFunction->Next = new PE_IMPORT_FUNCTION_ENTRY();
        importFunction = importFunction->Next;
        importFunction->Name = functions[i];
    }
    importFunction->Next = nullptr;
}

void PEFile::Commit()
{
    ComputeReservedData();
    ComputeHeaders();
    ComputeSectionTable();
}

PEResult PEFile::ReadFile(std::filesystem::path filePath)
{
    // Open file
    std::ifstream file(filePath, std::ios::binary | std::ios::ate);
    if (!file)
    {
        return PEResult::ErrorReadFileOpen;
    }

    auto fileSize = file.tellg();
    file.seekg(0);

    // Alloc memory
    m_loadedPeFile = (int8_t*)VirtualAlloc(NULL, fileSize, MEM_COMMIT, PAGE_EXECUTE_READWRITE);
    if (!m_loadedPeFile)
    {
        file.close();
        return PEResult::ErrorReadFileAlloc;
    }

    // Read contents into memory
    file.read((char*)m_loadedPeFile, fileSize);
    if (!file)
    {
        file.close();
        return PEResult::ErrorReadFileData;
    }

    file.close();

    return PEResult::Success;
}

PEResult PEFile::IsValid()
{
    // Check if DOS Stub and PE header signatures are valid
    if (m_dosHeader.e_magic != IMAGE_DOS_SIGNATURE || m_ntHeaders.Signature != IMAGE_NT_SIGNATURE)
    {
        UnloadFile();
        return PEResult::ErrorInvalidFileSignature;
    }

    if (m_ntHeaders.FileHeader.NumberOfSections > MAX_SECTIONS)
    {
        UnloadFile();
        return PEResult::ErrorInvalidFileTooManySections;
    }

    return PEResult::Success;
}

PEResult PEFile::ReadAll()
{
    PEResult rc = ReadHeaders();
    if (rc != PEResult::Success)
        return rc;

    ReadSections();

    return ReadImports();
}

PEResult PEFile::ReadHeaders()
{
    // Read DOS Stub
    memcpy(&m_dosHeader, m_loadedPeFile, sizeof(IMAGE_DOS_HEADER));
    m_dosStub.RawData = m_loadedPeFile + sizeof(IMAGE_DOS_HEADER);
    m_dosStub.Size = m_dosHeader.e_lfanew - sizeof(IMAGE_DOS_HEADER);

    // Read PE headers
    memcpy(&m_ntHeaders, m_loadedPeFile + m_dosHeader.e_lfanew, sizeof(IMAGE_NT_HEADERS));

    // Check if the loaded file is a PE file
    PEResult rc = IsValid();
    if (rc != PEResult::Success) {
        return rc;
    }

    // Load section table
    memset(m_sectionTable, 0, sizeof(m_sectionTable));
    memcpy(m_sectionTable, m_loadedPeFile + m_dosHeader.e_lfanew + sizeof(IMAGE_NT_HEADERS), m_ntHeaders.FileHeader.NumberOfSections * sizeof(IMAGE_SECTION_HEADER));

    return PEResult::Success;
}

void PEFile::ReadSections()
{
    DWORD reservedDataOffset = m_dosHeader.e_lfanew + sizeof(IMAGE_NT_HEADERS) + m_ntHeaders.FileHeader.NumberOfSections * sizeof(IMAGE_SECTION_HEADER);

    m_reservedData.Offset = reservedDataOffset;
    m_reservedData.RawData = m_loadedPeFile + reservedDataOffset;
    
    if (m_sectionTable[0].PointerToRawData > 0)
    {
        m_reservedData.Size = m_sectionTable[0].PointerToRawData - reservedDataOffset;
    }
    else
    {
        m_reservedData.Size = m_sectionTable[0].VirtualAddress - reservedDataOffset;
    }

    // Load sections
    for (int i = 0; i < m_ntHeaders.FileHeader.NumberOfSections; i++)
    {
        m_sections[i].Offset = m_sectionTable[i].PointerToRawData;
        m_sections[i].RawData = m_loadedPeFile + m_sectionTable[i].PointerToRawData;
        m_sections[i].Size = m_sectionTable[i].SizeOfRawData;
    }
}

PEResult PEFile::ReadImports()
{
    DWORD tableRVA = m_ntHeaders.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT].VirtualAddress;
    DWORD tableOffset = RvaToOffset(tableRVA);
    if (tableOffset == 0)
    {
        return PEResult::ErrorReadImportsTableOffset;
    }

    memset(&m_importTable, 0, sizeof(PE_IMPORT_DLL_ENTRY));

    IMAGE_IMPORT_DESCRIPTOR* importDesc = (IMAGE_IMPORT_DESCRIPTOR*)(m_loadedPeFile + tableOffset);
    IMAGE_THUNK_DATA* importThunk;
    PE_IMPORT_DLL_ENTRY* importDll = &this->m_importTable;
    PE_IMPORT_FUNCTION_ENTRY* importFunction;

    while (true)
    {
        importDll->Name = (char*)(m_loadedPeFile + RvaToOffset(importDesc->Name));
        if (importDesc->OriginalFirstThunk > 0)
        {
            importThunk = (IMAGE_THUNK_DATA*)(m_loadedPeFile + RvaToOffset(importDesc->OriginalFirstThunk));
        }
        else
        {
            importThunk = (IMAGE_THUNK_DATA*)(m_loadedPeFile + RvaToOffset(importDesc->FirstThunk));
        }

        importDll->Functions = new PE_IMPORT_FUNCTION_ENTRY();
        memset(importDll->Functions, 0, sizeof(PE_IMPORT_FUNCTION_ENTRY));
        importFunction = importDll->Functions;
        while (true)
        {
            if ((importThunk->u1.Ordinal & IMAGE_ORDINAL_FLAG32) == IMAGE_ORDINAL_FLAG32)
            {
                importFunction->Id = IMAGE_ORDINAL32(importThunk->u1.Ordinal);
            }
            else
            {
                DWORD nameOffset = RvaToOffset(importThunk->u1.AddressOfData);
                importFunction->Name = (char*)(m_loadedPeFile + nameOffset + 2);
            }

            importThunk = (IMAGE_THUNK_DATA*)((char*)importThunk + sizeof(IMAGE_THUNK_DATA));
            if (importThunk->u1.AddressOfData == 0)
            {
                break;
            }
            importFunction->Next = new PE_IMPORT_FUNCTION_ENTRY();
            memset(importFunction->Next, 0, sizeof(PE_IMPORT_FUNCTION_ENTRY));
            importFunction = importFunction->Next;
        }

        importDesc = (IMAGE_IMPORT_DESCRIPTOR*)((char*)importDesc + sizeof(IMAGE_IMPORT_DESCRIPTOR));
        if (importDesc->Name == 0)
        {
            break;
        }
        importDll->Next = new PE_IMPORT_DLL_ENTRY();
        memset(importDll->Next, 0, sizeof(PE_IMPORT_DLL_ENTRY));
        importDll = importDll->Next;
    }

    return PEResult::Success;
}

void PEFile::RebuildImportTable()
{
    // Calculate new import size
    DWORD sizeDlls = 0;
    DWORD sizeFunctions = 0;
    DWORD sizeStrings = 0;
    DWORD newImportsSize = CalculateAdditionalImportsSize(sizeDlls, sizeFunctions, sizeStrings);

    // Calculate current import size
    DWORD currentImportDllsSize = 0;
    PE_IMPORT_DLL_ENTRY* importDll = &this->m_importTable;
    while (importDll != nullptr)
    {
        currentImportDllsSize += sizeof(IMAGE_IMPORT_DESCRIPTOR);
        importDll = importDll->Next;
    }

    // Overwrite import section
    int index = AddSection(IMPORT_SECTION_NAME, currentImportDllsSize + newImportsSize, false);

    // Copy old imports
    DWORD oldImportTableRVA = m_ntHeaders.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT].VirtualAddress;
    DWORD oldImportTableOffset = RvaToOffset(oldImportTableRVA);
    memcpy(m_sections[index].RawData, m_loadedPeFile + oldImportTableOffset, currentImportDllsSize);

    // Copy new imports into the import section
    char* newImportsData = BuildAdditionalImports(m_sectionTable[index].VirtualAddress + currentImportDllsSize);
    memcpy(m_sections[index].RawData + currentImportDllsSize, newImportsData, newImportsSize);

    m_ntHeaders.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT].VirtualAddress = m_sectionTable[index].VirtualAddress;
    m_ntHeaders.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT].Size = m_sectionTable[index].SizeOfRawData;
    m_ntHeaders.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IAT].VirtualAddress = 0;
    m_ntHeaders.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IAT].Size = 0;
}

char* PEFile::BuildAdditionalImports(DWORD baseRVA)
{
    Commit();

    IMAGE_IMPORT_DESCRIPTOR importDesc;
    IMAGE_THUNK_DATA importThunk;
    PE_IMPORT_DLL_ENTRY* importDll;
    PE_IMPORT_FUNCTION_ENTRY* importFunction;

    DWORD sizeDlls = 0;
    DWORD sizeFunctions = 0;
    DWORD sizeStrings = 0;
    DWORD newImportsSize = CalculateAdditionalImportsSize(sizeDlls, sizeFunctions, sizeStrings);
    DWORD offsetDlls = 0;
    DWORD offsetFunctions = sizeDlls;
    DWORD offsetStrings = sizeDlls + 2 * sizeFunctions;

    char* buffer = new char[newImportsSize];
    memset(buffer, 0, newImportsSize);

    importDll = &m_additionalImports;
    while (importDll != nullptr)
    {
        memset(&importDesc, 0, sizeof(IMAGE_IMPORT_DESCRIPTOR));
        importDesc.OriginalFirstThunk = baseRVA + offsetFunctions;
        importDesc.FirstThunk = baseRVA + offsetFunctions + sizeFunctions;
        importDesc.Name = baseRVA + offsetStrings;
        memcpy(buffer + offsetStrings, importDll->Name, strlen(importDll->Name));
        offsetStrings += AlignNumber((DWORD)strlen(importDll->Name) + 1, 2);

        memcpy(buffer + offsetDlls, &importDesc, sizeof(IMAGE_IMPORT_DESCRIPTOR));
        offsetDlls += sizeof(IMAGE_IMPORT_DESCRIPTOR);

        importFunction = importDll->Functions;
        while (importFunction != nullptr)
        {
            memset(&importThunk, 0, sizeof(IMAGE_THUNK_DATA));
            if (importFunction->Id != 0)
            {
                importThunk.u1.Ordinal = importFunction->Id | IMAGE_ORDINAL_FLAG32;
            }
            else
            {
                importThunk.u1.AddressOfData = baseRVA + offsetStrings;
                memcpy(buffer + offsetStrings + 2, importFunction->Name, strlen(importFunction->Name));
                offsetStrings += 2 + AlignNumber((DWORD)strlen(importFunction->Name) + 1, 2);
            }

            memcpy(buffer + offsetFunctions, &importThunk, sizeof(IMAGE_THUNK_DATA));
            memcpy(buffer + offsetFunctions + sizeFunctions, &importThunk, sizeof(IMAGE_THUNK_DATA));
            offsetFunctions += sizeof(IMAGE_THUNK_DATA);

            importFunction = importFunction->Next;
        }
        offsetFunctions += sizeof(IMAGE_THUNK_DATA);

        importDll = importDll->Next;
    }

    return buffer;
}

DWORD PEFile::CalculateAdditionalImportsSize(DWORD& sizeDlls, DWORD& sizeFunctions, DWORD& sizeStrings)
{
    PE_IMPORT_DLL_ENTRY* importDll = &this->m_additionalImports;
    PE_IMPORT_FUNCTION_ENTRY* importFunction;

    // Calculate size
    while (importDll != nullptr)
    {
        sizeDlls += sizeof(IMAGE_IMPORT_DESCRIPTOR);
        sizeStrings += AlignNumber((DWORD)strlen(importDll->Name) + 1, 2);
        importFunction = importDll->Functions;
        while (importFunction != nullptr)
        {
            sizeFunctions += sizeof(IMAGE_THUNK_DATA);
            if (importFunction->Id == 0)
            {
                sizeStrings += 2 + AlignNumber((DWORD)strlen(importFunction->Name) + 1, 2);
            }
            importFunction = importFunction->Next;
        }
        sizeFunctions += sizeof(IMAGE_THUNK_DATA);
        importDll = importDll->Next;
    }
    sizeDlls += sizeof(IMAGE_IMPORT_DESCRIPTOR);

    return sizeDlls + 2 * sizeFunctions + sizeStrings;
}

bool PEFile::WritePadding(std::ofstream& file, long paddingSize)
{
    if (paddingSize <= 0)
        return false;

    char* padding = new char[paddingSize];
    memset(padding, 0, paddingSize);
    if (file.write(padding, paddingSize))
    {
        return false;
    }
    delete padding;

    return true;
}

DWORD PEFile::AlignNumber(DWORD number, DWORD alignment)
{
    return (DWORD)(ceil(number / (alignment + 0.0)) * alignment);
}

DWORD PEFile::RvaToOffset(DWORD rva) {
    for (int i = 0; i < m_ntHeaders.FileHeader.NumberOfSections; i++)
    {
        if (rva >= m_sectionTable[i].VirtualAddress && rva < m_sectionTable[i].VirtualAddress + m_sectionTable[i].Misc.VirtualSize)
        {
            return m_sectionTable[i].PointerToRawData + (rva - m_sectionTable[i].VirtualAddress);
        }
    }

    return 0;
}

DWORD PEFile::OffsetToRVA(DWORD offset)
{
    for (int i = 0; i < m_ntHeaders.FileHeader.NumberOfSections; i++)
    {
        if (offset >= m_sectionTable[i].PointerToRawData &&
            offset < m_sectionTable[i].PointerToRawData + m_sectionTable[i].SizeOfRawData)
        {
            return m_sectionTable[i].VirtualAddress + (offset - m_sectionTable[i].PointerToRawData);
        }
    }

    return 0;
}

void PEFile::ComputeReservedData()
{
    DWORD dirIndex = 0;
    for (dirIndex = 0; dirIndex < m_ntHeaders.OptionalHeader.NumberOfRvaAndSizes; dirIndex++)
    {
        if (m_ntHeaders.OptionalHeader.DataDirectory[dirIndex].VirtualAddress > 0 &&
            m_ntHeaders.OptionalHeader.DataDirectory[dirIndex].VirtualAddress >= m_reservedData.Offset &&
            m_ntHeaders.OptionalHeader.DataDirectory[dirIndex].VirtualAddress < m_reservedData.Size)
        {
            break;
        }
    }

    if (dirIndex == m_ntHeaders.OptionalHeader.NumberOfRvaAndSizes)
    {
        return;
    }

    int sectionIndex = AddSection(RESERV_SECTION_NAME, m_reservedData.Size, false);
    memcpy(m_sections[sectionIndex].RawData, m_reservedData.RawData, m_reservedData.Size);

    for (dirIndex = 0; dirIndex < m_ntHeaders.OptionalHeader.NumberOfRvaAndSizes; dirIndex++)
    {
        if (m_ntHeaders.OptionalHeader.DataDirectory[dirIndex].VirtualAddress > 0 &&
            m_ntHeaders.OptionalHeader.DataDirectory[dirIndex].VirtualAddress >= m_reservedData.Offset &&
            m_ntHeaders.OptionalHeader.DataDirectory[dirIndex].VirtualAddress < m_reservedData.Size)
        {
            m_ntHeaders.OptionalHeader.DataDirectory[dirIndex].VirtualAddress += m_sectionTable[sectionIndex].VirtualAddress - m_reservedData.Offset;
        }
    }

    m_reservedData.Size = 0;
}

void PEFile::ComputeHeaders()
{
    m_ntHeaders.OptionalHeader.SizeOfHeaders = AlignNumber(m_dosHeader.e_lfanew + m_ntHeaders.FileHeader.SizeOfOptionalHeader +
        m_ntHeaders.FileHeader.NumberOfSections * sizeof(IMAGE_SECTION_HEADER), m_ntHeaders.OptionalHeader.FileAlignment);

    DWORD imageSize = m_ntHeaders.OptionalHeader.SizeOfHeaders;
    for (int i = 0; i < m_ntHeaders.FileHeader.NumberOfSections; i++)
    {
        imageSize += AlignNumber(m_sectionTable[i].Misc.VirtualSize, m_ntHeaders.OptionalHeader.SectionAlignment);
    }
    m_ntHeaders.OptionalHeader.SizeOfImage = AlignNumber(imageSize, m_ntHeaders.OptionalHeader.SectionAlignment);

    m_ntHeaders.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_BOUND_IMPORT].VirtualAddress = 0;
    m_ntHeaders.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_BOUND_IMPORT].Size = 0;
}

void PEFile::ComputeSectionTable()
{
    DWORD offset = m_ntHeaders.OptionalHeader.SizeOfHeaders;
    for (int i = 0; i < m_ntHeaders.FileHeader.NumberOfSections; i++)
    {
        m_sectionTable[i].Characteristics |= IMAGE_SCN_MEM_WRITE;
        offset = AlignNumber(offset, m_ntHeaders.OptionalHeader.FileAlignment);
        m_sectionTable[i].PointerToRawData = offset;
        offset += m_sectionTable[i].SizeOfRawData;
    }
}