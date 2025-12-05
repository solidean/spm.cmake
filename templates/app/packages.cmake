# load the package manager code
include(${CMAKE_CURRENT_SOURCE_DIR}/spm.cmake)

# =========================
# Packages begin
# =========================

# Shaped Package Manager
spm_package(
    NAME spm.cmake
    GIT_URL https://github.com/solidean/spm.cmake.git
    COMMIT dfc52ee09fe3da37638d8d7d0c6176c59a367562
    UPDATE_REF main
)

# Modern C++23 standard-library alternative with sane defaults, strong checks, and no legacy baggage.
spm_package(
    NAME clean-core
    GIT_URL https://github.com/solidean/clean-core.git
    COMMIT 95634878ea373ec7ede212b77de7f5d407d0bb48
    UPDATE_REF main
)

# =========================
# Packages end
# =========================

# verifies constraints
# and other global tasks
spm_finalize()
