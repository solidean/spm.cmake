# SPM Integration Functions
#
# This file includes all CMake integration functionality for use in CMakeLists.txt
# (spm_package, spm_require, spm_finalize)
#
# Include guard for include-once behavior
if(DEFINED SPM_INTEGRATION_INCLUDED)
    return()
endif()
set(SPM_INTEGRATION_INCLUDED TRUE)

include(${CMAKE_CURRENT_LIST_DIR}/common/helpers.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/common/git.cmake)

include(${CMAKE_CURRENT_LIST_DIR}/integration/package.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/integration/require.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/integration/finalize.cmake)
