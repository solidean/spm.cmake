cmake_minimum_required(VERSION 3.28)
project(@PROJECT_SLUG@ LANGUAGES CXX)

# require C++23
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_executable(@PROJECT_SLUG@
    src/main.cc
    src/@PROJECT_SLUG@/dummy.cc
    src/@PROJECT_SLUG@/dummy.hh
)

# expose "src" so <@PROJECT_SLUG@/dummy.hh> works
target_include_directories(@PROJECT_SLUG@
    PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/src"
)
