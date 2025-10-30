cmake_minimum_required(VERSION 3.14)
project(vst3_host)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find VST3 SDK (relative path from this CMakeLists.txt)
set(VST3_SDK_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../vst3sdk")

if(NOT EXISTS "${VST3_SDK_DIR}/CMakeLists.txt")
    message(FATAL_ERROR "VST3 SDK not found at ${VST3_SDK_DIR}")
endif()

# Add VST3 SDK subdirectory
# Note: We need to build a minimal set of VST3 SDK components
set(SMTG_CREATE_VST2_VERSION OFF CACHE BOOL "" FORCE)
set(SMTG_ADD_VST3_PLUGINS_SAMPLES OFF CACHE BOOL "" FORCE)
set(SMTG_ADD_VST3_HOSTING_SAMPLES OFF CACHE BOOL "" FORCE)

# Include VST3 SDK
add_subdirectory(${VST3_SDK_DIR} vst3sdk_build EXCLUDE_FROM_ALL)

# Our VST3 host library
add_library(vst3_host STATIC
    vst3_host.cpp
    vst3_host.h
)

# Include directories
target_include_directories(vst3_host PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${VST3_SDK_DIR}
)

# Link against VST3 SDK components
target_link_libraries(vst3_host
    sdk_hosting
    sdk
    base
)

# Platform-specific settings
if(APPLE)
    find_library(COREFOUNDATION_FRAMEWORK CoreFoundation)
    find_library(FOUNDATION_FRAMEWORK Foundation)

    target_link_libraries(vst3_host
        ${COREFOUNDATION_FRAMEWORK}
        ${FOUNDATION_FRAMEWORK}
    )

    # Set macOS deployment target
    set_target_properties(vst3_host PROPERTIES
        MACOSX_DEPLOYMENT_TARGET "10.13"
    )
endif()

# Compiler flags
if(CMAKE_CXX_COMPILER_ID MATCHES "Clang|GNU")
    target_compile_options(vst3_host PRIVATE
        -Wall
        -Wextra
        -Wno-unused-parameter
    )
endif()

# Output library to predictable location
set_target_properties(vst3_host PROPERTIES
    ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
)

# Install targets
install(TARGETS vst3_host
    ARCHIVE DESTINATION lib
)

install(FILES vst3_host.h
    DESTINATION include
)
