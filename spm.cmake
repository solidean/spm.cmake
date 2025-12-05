# Shaped Package Manager (SPM)
# A lightweight, opinionated package manager based purely on CMake
#
# Usage: cmake -P spm.cmake -- <command> [args...]
# Example: cmake -P spm.cmake -- init

cmake_minimum_required(VERSION 3.28)

# Script mode is "spm-as-a-package-manager"
if(CMAKE_SCRIPT_MODE_FILE)

    # Find the "--" separator
    math(EXPR last_index "${CMAKE_ARGC} - 1")
    set(separator_index -1)
    foreach(i RANGE 0 ${last_index})
        if("${CMAKE_ARGV${i}}" STREQUAL "--")
            set(separator_index ${i})
            break()
        endif()
    endforeach()

    if(separator_index EQUAL -1)
        message(FATAL_ERROR "Missing '--' separator. Usage: cmake -P spm.cmake -- <command> [args...]")
    endif()

    # Extract command and arguments after "--"
    math(EXPR command_index "${separator_index} + 1")
    if(command_index GREATER last_index)
        message(FATAL_ERROR "No command specified. Usage: cmake -P spm.cmake -- <command> [args...]")
    endif()

    set(spm_command "${CMAKE_ARGV${command_index}}")

    # Collect remaining arguments
    set(spm_args "")
    math(EXPR args_start_index "${command_index} + 1")
    if(args_start_index LESS_EQUAL last_index)
        foreach(i RANGE ${args_start_index} ${last_index})
            list(APPEND spm_args "${CMAKE_ARGV${i}}")
        endforeach()
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


else() # Include mode is the cmake function to have package deps inside CMakeLists.txt

    # This is a bit weird setup
    # We expect apps to keep their spm.cmake in the root (that is copied and might be an old version)
    # Then they have a current-ish extern/spm.cmake/spm.cmake as a package
    # This file must work from both perspectives!
    # SPM itself has no extern, so that's our criterion
    if(EXISTS "${CMAKE_CURRENT_LIST_DIR}/extern/spm.cmake/spm.cmake")
        # we're in the top-level spm.cmake and need to go into the actual package
        include("${CMAKE_CURRENT_LIST_DIR}/extern/spm.cmake/spm.cmake")
    elseif(EXISTS "${CMAKE_CURRENT_LIST_DIR}/cmake/root.cmake")
        # we're in the package spm.cmake => we load cmake/root.cmake, which includes all that's needed for managing the app + packages
        include("${CMAKE_CURRENT_LIST_DIR}/cmake/root.cmake")
    else()
        message(FATAL_ERROR "SPM setup is broken: neither extern/spm.cmake/spm.cmake nor cmake/root.cmake exists. Please run 'cmake -P spm.cmake -- init' to initialize SPM properly.")
    endif()

endif()
