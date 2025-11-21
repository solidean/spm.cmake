# load the package manager code
include(${CMAKE_CURRENT_SOURCE_DIR}/spm.cmake)

# =========================
# Packages begin
# =========================

spm_package(
    NAME clean-core
    GIT_URL https://github.com/project-arcana/clean-core.git
    COMMIT dfc52ee09fe3da37638d8d7d0c6176c59a367562
    UPDATE_REF main
)

# =========================
# Packages end
# =========================

# verifies constraints
# and other global tasks
spm_finalize()
