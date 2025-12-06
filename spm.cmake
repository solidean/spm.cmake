# Shaped Package Manager (SPM)
# A lightweight, opinionated package manager based purely on CMake
#
# Application Quickstart:
#   1. Copy spm.cmake into your repo (can be empty)
#   2. Run: cmake -P spm.cmake -- init-app my-app ma
#      - my-app is the slug (project name, binary name, include prefix)
#      - ma is the default namespace (2-4 chars, uppercased for CMake options)
#
# Usage: cmake -P spm.cmake -- <command> [args...]
# Commands: init, init-app, init-lib, update, vendor, status, fetch

cmake_minimum_required(VERSION 3.28)

# Script mode is "spm-as-a-package-manager"
if(CMAKE_SCRIPT_MODE_FILE)

    # Argument parsing strategy:
    # We parse arguments here in the outer (user's root) spm.cmake, and they will
    # be re-parsed when we include the inner (up-to-date) spm.cmake from extern/.
    # This is intentional:
    # - The outer parse is minimal and stable (needed for "init" bootstrap)
    # - The inner parse can evolve over time with better arg handling
    # - Goal: user's root spm.cmake remains constant over years, even as SPM evolves

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

        # Two-tier execution model:
        # This code runs in BOTH the outer (user's root) and inner (SPM package) contexts.
        # - Outer: stable bootloader that delegates to the up-to-date version
        # - Inner: actual implementation that can evolve freely
        # The outer includes the inner, which re-parses args and executes the command.

        # Check if we're in user's root spm.cmake (has extern/) or the actual SPM repo (has cmake/cli.cmake)
        if(EXISTS "${CMAKE_CURRENT_LIST_DIR}/extern/spm.cmake/spm.cmake")
            # We're in the top-level spm.cmake, delegate to the actual package
            # This will re-include spm.cmake from extern/, which will parse args and dispatch
            # (we don't call spm_dispatch_command here; the inner spm.cmake will do it)
            include("${CMAKE_CURRENT_LIST_DIR}/extern/spm.cmake/spm.cmake")
        elseif(EXISTS "${CMAKE_CURRENT_LIST_DIR}/cmake/cli.cmake")
            # We're in the SPM package itself (up-to-date version), load the CLI infrastructure
            include("${CMAKE_CURRENT_LIST_DIR}/cmake/cli.cmake")
            # Execute the requested command (only when we load cli.cmake directly)
            spm_dispatch_command(${spm_command} ${spm_args})
        else()
            message(FATAL_ERROR "SPM not initialized. Run 'cmake -P spm.cmake -- init' first.")
        endif()
    endif()


else() # Include mode is the cmake function to have package deps inside CMakeLists.txt

    # Integration mode (include from CMakeLists.txt):
    # Similar two-tier model as script mode above.
    # - User's root spm.cmake may be old/stale (copied once, rarely updated)
    # - extern/spm.cmake/spm.cmake is the up-to-date version (updated via git)
    # This file (spm.cmake) must work correctly from BOTH perspectives:
    #   1. When included from user's CMakeLists.txt → delegates to extern/
    #   2. When included as the SPM package itself → loads integration functions
    # We detect which context we're in by checking for extern/spm.cmake/spm.cmake.
    # SPM itself has no extern/, so that's our distinguishing criterion.

    if(EXISTS "${CMAKE_CURRENT_LIST_DIR}/extern/spm.cmake/spm.cmake")
        # We're in the top-level (user's root) spm.cmake → delegate to actual package
        include("${CMAKE_CURRENT_LIST_DIR}/extern/spm.cmake/spm.cmake")
    elseif(EXISTS "${CMAKE_CURRENT_LIST_DIR}/cmake/integration.cmake")
        # We're in the SPM package itself → load integration functions
        # (cmake/integration.cmake includes package.cmake, require.cmake, finalize.cmake)
        include("${CMAKE_CURRENT_LIST_DIR}/cmake/integration.cmake")
    else()
        message(FATAL_ERROR "SPM setup is broken: neither extern/spm.cmake/spm.cmake nor cmake/integration.cmake exists. Please run 'cmake -P spm.cmake -- init' to initialize SPM properly.")
    endif()

endif()
