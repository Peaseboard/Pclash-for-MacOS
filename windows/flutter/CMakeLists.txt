# This file controls Flutter-specific build configuration for Windows.

cmake_minimum_required(VERSION 3.14)

# The name of the executable created for the application.
set(BINARY_NAME "pclash")

# Use the same build type as the parent.
set(CMAKE_BUILD_TYPE "${CMAKE_BUILD_TYPE}" PARENT_SCOPE)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}" PARENT_SCOPE)
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS}" PARENT_SCOPE)

# Flutter SDK path (can be overridden by CMake or environment).
if(NOT FLUTTER_SDK)
  if(DEFINED ENV{FLUTTER_ROOT})
    set(FLUTTER_SDK "$ENV{FLUTTER_ROOT}")
  else()
    message(FATAL_ERROR "FLUTTER_SDK not set and FLUTTER_ROOT environment variable not defined.")
  endif()
endif()

# Include the Flutter tools.
include("${FLUTTER_SDK}/packages/flutter_tools/cmake/flutter_windows.cmake")

# This is the entry point for the Flutter app.
set(FLUTTER_ROOT "${FLUTTER_SDK}")
set(DART_OBFUSCATION FALSE)
set(TREE_SHAKE_ICONS FALSE)
set(FLUTTER_BUILD_MODE "debug")

# Generate the flutter_assemble target.
flutter_assemble(
  OUT_DIR "${CMAKE_BINARY_DIR}/flutter"
  BUILD_MODE "debug"
  FLUTTER_TARGET "lib/main.dart"
  FLUTTER_SDK "${FLUTTER_SDK}"
  ICC_OUTPUT "${CMAKE_BINARY_DIR}/flutter/ephemeral/icudtl.dat"
  OUTPUT "${CMAKE_BINARY_DIR}/flutter/flutter_assemble"
)

# Create a library for the flutter DLL and data.
add_library(flutter INTERFACE)
target_include_directories(flutter INTERFACE
  "${CMAKE_BINARY_DIR}/flutter/ephemeral"
)
target_link_directories(flutter INTERFACE
  "${CMAKE_BINARY_DIR}/flutter/ephemeral"
)
target_link_libraries(flutter INTERFACE
  flutter_windows.dll
)

# Add a dependency on the assemble target.
add_dependencies(flutter flutter_assemble)

# Copy the DLL and icudtl.dat to the build output.
add_custom_command(TARGET flutter_assemble POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${CMAKE_BINARY_DIR}/flutter/ephemeral/flutter_windows.dll"
    "$<TARGET_FILE_DIR:${BINARY_NAME}>/flutter_windows.dll"
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${CMAKE_BINARY_DIR}/flutter/ephemeral/icudtl.dat"
    "$<TARGET_FILE_DIR:${BINARY_NAME}>/icudtl.dat"
)

# Plugin registration.
set(PLUGIN_BUNDLED_LIBRARIES "")
set(PLUGIN_SHARED_LIBRARIES "")
set(EXPLICIT_PLUGINS "")

# Generate the plugin registration.
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/generated_plugin_registrant.cc"
  "// Generated file. Do not edit.\n"
  "#include \"generated_plugin_registrant.h\"\n"
)
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/generated_plugin_registrant.h"
  "// Generated file. Do not edit.\n"
  "#ifndef GENERATED_PLUGIN_REGISTRANT_H_\n"
  "#define GENERATED_PLUGIN_REGISTRANT_H_\n"
  "\n"
  "// Registers plugins.\n"
  "void RegisterPlugins(flutter::PluginRegistry* registry);\n"
  "\n"
  "#endif  // GENERATED_PLUGIN_REGISTRANT_H_\n"
)

# Generate the plugins cmake file.
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/generated_plugins.cmake"
  "# Generated file. Do not edit.\n"
  "\n"
  "set(PLUGIN_BUNDLED_LIBRARIES ${PLUGIN_BUNDLED_LIBRARIES} PARENT_SCOPE)\n"
  "set(PLUGIN_SHARED_LIBRARIES ${PLUGIN_SHARED_LIBRARIES} PARENT_SCOPE)\n"
)

# Export generated plugins.
set(FLUTTER_PLUGIN_LIST "")
configure_file(
  "${CMAKE_CURRENT_BINARY_DIR}/generated_plugins.cmake"
  "${CMAKE_CURRENT_SOURCE_DIR}/generated_plugins.cmake"
  COPYONLY
)
