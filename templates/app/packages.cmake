# load the package manager code
include(${CMAKE_CURRENT_SOURCE_DIR}/spm.cmake)

# =========================
# Packages begin
# =========================
#
# spm_package usage:
#   spm_package(
#       NAME    clean-core
#       GIT_URL https://github.com/solidean/clean-core.git
#       COMMIT  95634878ea373ec7ede212b77de7f5d407d0bb48
#       [CHECKOUT NESTED|VENDORED]
#       [UPDATE_REF <branch>]
#       [NO_ADD_SUBDIRECTORY]
#   )
#
# Parameters:
#   NAME: Package identifier (must match ^[A-Za-z0-9_.-]+$)
#   GIT_URL: Git repository URL to fetch from
#   COMMIT: Specific commit hash to checkout
#   CHECKOUT: How to manage the package (see modes below)
#   UPDATE_REF: Branch name for reference (used by update commands)
#   NO_ADD_SUBDIRECTORY: Skip calling add_subdirectory() for manual control
#
# Checkout modes:
#   NESTED (default): full git checkout (nested repo) populated from local git cache, auto-updates when commit changes
#   VENDORED: snapshot without .git, becomes part of main repo, managed manually (switching requires SPM CLI)
#


# Shaped Package Manager
spm_package(
    NAME spm.cmake
    GIT_URL https://github.com/solidean/spm.cmake.git
    COMMIT 3daf094d3dc0db026c1f632603efd32bcb33c71c
    UPDATE_REF main
    NO_ADD_SUBDIRECTORY
)

# Modern C++23 standard-library alternative with sane defaults, strong checks, and no legacy baggage.
spm_package(
    NAME clean-core
    GIT_URL https://github.com/solidean/clean-core.git
    COMMIT 7cb6f36bc70d54cc16438dfe1b4765b653203195
    UPDATE_REF main
)

# Unified test, fuzz, benchmark, and app runner for modern C++.
spm_package(
    NAME nexus
    GIT_URL https://github.com/solidean/nexus.git
    COMMIT f16c5e5052487321a92451c56a41021cdef76148
    UPDATE_REF main
)


# =========================
# Packages end
# =========================

# verifies constraints
# and other global tasks
spm_finalize()
