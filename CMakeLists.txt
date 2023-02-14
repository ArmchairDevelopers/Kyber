cmake_minimum_required(VERSION 3.15)

project(
	Kyber
	DESCRIPTION "Private servers for STAR WARS Battlefront II"
	HOMEPAGE_URL "https://github.com/BattleDash/Kyber"
	LANGUAGES C CXX
)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

include_directories(
        ${PROJECT_SOURCE_DIR}/Source/Public
)
include_directories(SYSTEM INTERFACE
        ${PROJECT_SOURCE_DIR}/Libraries/Include
)

file(GLOB_RECURSE DLL_SOURCES CONFIGURE_DEPENDS
        ${PROJECT_SOURCE_DIR}/Source/Private/*.cpp
)
file(GLOB_RECURSE INCLUDE_SOURCES CONFIGURE_DEPENDS
        ${PROJECT_SOURCE_DIR}/Libraries/Sources/*.cpp
)

# Begone
add_compile_definitions(_SILENCE_CXX17_CODECVT_HEADER_DEPRECATION_WARNING)

add_library(Kyber MODULE ${DLL_SOURCES} ${INCLUDE_SOURCES})

file(GLOB_RECURSE LIBRARIES CONFIGURE_DEPENDS
        ${PROJECT_SOURCE_DIR}/Libraries/Binaries/*.lib
)

set_target_properties(Kyber PROPERTIES LINK_FLAGS "/ignore:4075 /ignore:4098 /LTCG")
target_link_libraries(Kyber Ws2_32.lib d3d11.lib dxgi.lib ${LIBRARIES})

add_subdirectory(Launcher)
add_subdirectory(Installer)