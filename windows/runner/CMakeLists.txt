cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

# Define the application target. To change the name, change BINARY_NAME in the
# top-level CMakeLists.txt, not here.
set(BINARY_NAME "pclash")

add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "proxy_plugin.cpp"
  "ProxyHelper.h"
  "proxy_plugin.h"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

# Apply standard C++ settings.
apply_standard_settings(${BINARY_NAME})

# Set the Windows subsystem.
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")

# Include the generated plugin registrant header.
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")

# Add dependencies on the Flutter wrapper libraries.
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)

# Link to required Windows libraries.
target_link_libraries(${BINARY_NAME} PRIVATE
  "dwmapi.lib"
)

# Enable the Windows manifest for the application.
set_target_properties(${BINARY_NAME} PROPERTIES
  VS_DPI_AWARE "ON"
)

# Install the application.
install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}" COMPONENT Runtime)
