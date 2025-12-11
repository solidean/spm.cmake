cmake_minimum_required(VERSION 3.28)
project(@PROJECT_SLUG@ LANGUAGES CXX)

# Enforce pure C++23 here; it's a clean modern baseline you can adjust anytime.
# Apps should set their exact language standard explicitly.
# Libraries only declare a minimum requirement, not a global mandate.
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# External packages, managed via SPM
include(${CMAKE_CURRENT_SOURCE_DIR}/packages.cmake)

# Application binary
# Source list only: CMake builds translation units, so list all .cc files here.
# Headers aren't needed: VS Code shows the filesystem and clangd uses compile_commands.json.
# This is an application target, so there’s no public API to expose via FILE_SET.
add_executable(@PROJECT_SLUG@
    src/main.cc
    src/@PROJECT_SLUG@/dummy.cc
)

# expose "src" so '#include <@PROJECT_SLUG@/dummy.hh>' works
target_include_directories(@PROJECT_SLUG@
    PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/src"
)

# link against dependencies (defined in packages.cmake)
target_link_libraries(@PROJECT_SLUG@
    PRIVATE
    clean-core
    nexus
)
