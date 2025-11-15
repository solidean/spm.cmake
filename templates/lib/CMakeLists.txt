cmake_minimum_required(VERSION 3.28)
project(@PROJECT_SLUG@ LANGUAGES CXX)

# dependencies
include("${CMAKE_SOURCE_DIR}/extern/spm.cmake/spm.cmake")
spm_require(clean-core dfc52ee09fe3da37638d8d7d0c6176c59a367562)

# Define the library and its sources
add_library(@PROJECT_SLUG@
    src/@PROJECT_SLUG@/dummy.cc
)

# Public headers live co-located in src/ for better editor experience.
# FILE_SET models the public API explicitly (install/export, IDEs, etc.).
target_sources(@PROJECT_SLUG@
    PUBLIC
    FILE_SET public_headers
    TYPE HEADERS
    BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/src"
    FILES
    src/@PROJECT_SLUG@/dummy.hh
    src/@PROJECT_SLUG@/fwd.hh
)

# Libraries should not set a global C++ standard here.
# Instead, declare a minimum on the target so parents stay in control.
# Require at least C++23 for this target; the final -std is chosen by the top-level project.
target_compile_features(@PROJECT_SLUG@
    PUBLIC
    cxx_std_23
)

# Expose "src" so '#include <@PROJECT_SLUG@/dummy.hh>' works for consumers.
target_include_directories(@PROJECT_SLUG@
    PUBLIC
    "${CMAKE_CURRENT_SOURCE_DIR}/src"
)
