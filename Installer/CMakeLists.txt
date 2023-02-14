cmake_minimum_required(VERSION 3.15)

project(
	KyberInstaller
	DESCRIPTION "Private servers for STAR WARS Battlefront II"
	HOMEPAGE_URL "https://github.com/BattleDash/Kyber"
	LANGUAGES C CXX
)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

include_directories(SYSTEM INTERFACE
        ${CMAKE_SOURCE_DIR}/Libraries/Include
)

file(GLOB_RECURSE INCLUDE_SOURCES CONFIGURE_DEPENDS
        ${CMAKE_SOURCE_DIR}/Libraries/Sources/*.cpp
)

file(GLOB_RECURSE DLL_HEADERS CONFIGURE_DEPENDS
        ${PROJECT_SOURCE_DIR}/*.h
)
file(GLOB_RECURSE DLL_SOURCES CONFIGURE_DEPENDS
        ${PROJECT_SOURCE_DIR}/*.cpp
)

add_executable(KyberInstaller WIN32 ${DLL_SOURCES} ${INCLUDE_SOURCES} ${DLL_HEADERS})

set_target_properties(KyberInstaller PROPERTIES LINK_FLAGS "/ignore:4098")
set(KYBER_BINARIES_DIR ${CMAKE_SOURCE_DIR}/Libraries/Binaries)
target_link_libraries(
    KyberInstaller
    ${KYBER_BINARIES_DIR}/libcrypto_static.lib
    ${KYBER_BINARIES_DIR}/libssl_static.lib
)