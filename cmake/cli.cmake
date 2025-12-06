# SPM CLI Functions
#
# This file includes all CLI-related functionality for the standalone tool
# (cmake -P spm.cmake -- cmd args...)
#
# Include guard for include-once behavior
if(DEFINED SPM_CLI_INCLUDED)
    return()
endif()
set(SPM_CLI_INCLUDED TRUE)

include(${CMAKE_CURRENT_LIST_DIR}/common/helpers.cmake)

# commands
include(${CMAKE_CURRENT_LIST_DIR}/cli/apply_template.cmake)

include(${CMAKE_CURRENT_LIST_DIR}/cli/dispatch_command.cmake)
