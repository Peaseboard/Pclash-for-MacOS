# Project-level configuration.
cmake_minimum_required(VERSION 3.10)
project(runner LANGUAGES CXX)

# The name of the executable created for the application.
set(BINARY_NAME "pclash")
# The unique GTK application identifier for this application.
set(APPLICATION_ID "com.pclash.app")

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.10...3.25)

# Load the PkgConfig module for finding system dependencies.
find_package(PkgConfig REQUIRED)

# Dart tooling variables.
set(DART_OBFUSCATION FALSE)
set(TREE_SHAKE_ICONS FALSE)
set(FLUTTER_BUILD_MODE "debug")

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# System-level dependencies.
pkg_check_modules(GTK REQUIRED IMPORTED_TARGET gtk+-3.0)
pkg_check_modules(GLIB REQUIRED IMPORTED_TARGET glib-2.0)
pkg_check_modules(GIO REQUIRED IMPORTED_TARGET gio-2.0)

# Application build.
add_executable(${BINARY_NAME}
  "main.cc"
  "my_application.cc"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
)
apply_standard_settings(${BINARY_NAME})
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK PkgConfig::GLIB PkgConfig::GIO)

# Run the Flutter tool to generate the plugin registrant.
add_dependencies(${BINARY_NAME} flutter_assemble)

# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
include(flutter/generated_plugins.cmake)

# === Installation ===
# Install the binary.
install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}/bin" COMPONENT Runtime)

# Install the desktop file.
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/pclash.desktop" DESTINATION "${CMAKE_INSTALL_PREFIX}/share/applications" COMPONENT Runtime)

# Install the icon.
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/data/icons/pclash.png" DESTINATION "${CMAKE_INSTALL_PREFIX}/share/icons/hicolor/128x128/apps" COMPONENT Runtime)
