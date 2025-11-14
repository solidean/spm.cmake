# Shaped Package Manager (SPM)
# A lightweight, opinionated package manager based purely on CMake
#
# Usage: cmake -P spm.cmake -- <command> [args...]
# Example: cmake -P spm.cmake -- init

cmake_minimum_required(VERSION 3.28)
if(NOT CMAKE_SCRIPT_MODE_FILE)
    message(FATAL_ERROR "Run via: cmake -P spm.cmake -- init")
endif()

# Parse command-line arguments
# Extract the command (first argument after --) and remaining arguments
list(LENGTH CMAKE_ARGV cmake_argc)
if(cmake_argc GREATER 3)
    list(GET CMAKE_ARGV 3 spm_command)
    if(cmake_argc GREATER 4)
        list(SUBLIST CMAKE_ARGV 4 -1 spm_args)
    else()
        set(spm_args "")
    endif()
else()
    message(FATAL_ERROR "No command specified. Usage: cmake -P spm.cmake -- <command> [args...]")
endif()

# Handle "init*" commands - Bootstrap SPM in the current project
if(spm_command MATCHES "^init")
    # Verify SPM is not already initialized
    if(EXISTS "${CMAKE_CURRENT_LIST_DIR}/extern/spm.cmake/spm.cmake")
        message(FATAL_ERROR "SPM already initialized. extern/spm.cmake/spm.cmake already exists.")
    endif()

    # Clone the SPM repository into the project's extern directory
    message(STATUS "Initializing SPM by cloning repository...")
    execute_process(
        COMMAND git clone https://github.com/solidean/spm.cmake.git extern/spm.cmake
        WORKING_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}"
        RESULT_VARIABLE git_result
    )
    if(NOT git_result EQUAL 0)
        message(FATAL_ERROR "Failed to clone spm.cmake repository")
    endif()

    # Execute the SPM init implementation
    include("${CMAKE_CURRENT_LIST_DIR}/extern/spm.cmake/cmake/init.cmake")


else() # Handle all other commands - Delegate to the SPM implementation

    # Verify SPM has been initialized
    if(NOT EXISTS "${CMAKE_CURRENT_LIST_DIR}/extern/spm.cmake/spm.cmake")
        message(FATAL_ERROR "SPM not initialized. Run 'cmake -P spm.cmake -- init' first.")
    endif()

    # Load the SPM implementation
    include("${CMAKE_CURRENT_LIST_DIR}/extern/spm.cmake/spm.cmake")

    # Execute the requested command
    spm_execute(${spm_command} ${spm_args})
endif()
