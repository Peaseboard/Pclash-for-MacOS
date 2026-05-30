# This file controls Flutter-specific build configuration for Linux.

cmake_minimum_required(VERSION 3.10)

set(BINARY_NAME "pclash")

# Flutter SDK path.
if(NOT FLUTTER_SDK)
  if(DEFINED ENV{FLUTTER_ROOT})
    set(FLUTTER_SDK "$ENV{FLUTTER_ROOT}")
  else()
    message(FATAL_ERROR "FLUTTER_SDK not set and FLUTTER_ROOT environment variable not defined.")
  endif()
endif()

include("${FLUTTER_SDK}/packages/flutter_tools/cmake/flutter_linux.cmake")

set(FLUTTER_ROOT "${FLUTTER_SDK}")
set(DART_OBFUSCATION FALSE)
set(TREE_SHAKE_ICONS FALSE)
set(FLUTTER_BUILD_MODE "debug")

flutter_assemble(
  OUT_DIR "${CMAKE_BINARY_DIR}/flutter"
  BUILD_MODE "debug"
  FLUTTER_TARGET "lib/main.dart"
  FLUTTER_SDK "${FLUTTER_SDK}"
  ICC_OUTPUT "${CMAKE_BINARY_DIR}/flutter/ephemeral/icudtl.dat"
  OUTPUT "${CMAKE_BINARY_DIR}/flutter/flutter_assemble"
)

add_library(flutter INTERFACE)
target_include_directories(flutter INTERFACE
  "${CMAKE_BINARY_DIR}/flutter/ephemeral"
)
target_link_directories(flutter INTERFACE
  "${CMAKE_BINARY_DIR}/flutter/ephemeral"
)
target_link_libraries(flutter INTERFACE flutter_linux)

add_dependencies(flutter flutter_assemble)

# Plugin registration.
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/generated_plugins.cmake"
  "# Generated file. Do not edit.\n"
  "\n"
  "set(PLUGIN_BUNDLED_LIBRARIES \"\" PARENT_SCOPE)\n"
  "set(PLUGIN_SHARED_LIBRARIES \"\" PARENT_SCOPE)\n"
)

configure_file(
  "${CMAKE_CURRENT_BINARY_DIR}/generated_plugins.cmake"
  "${CMAKE_CURRENT_SOURCE_DIR}/generated_plugins.cmake"
  COPYONLY
)
