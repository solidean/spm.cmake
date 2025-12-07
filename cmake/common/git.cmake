# spm_git_execute_or_fail(<error_context>
#                          COMMAND <git_command>...
#                          WORKING_DIRECTORY <dir>
#                          [OUTPUT_VARIABLE <var>]
#                          [ERROR_VARIABLE <var>])
#
# Helper function that executes a git command and automatically handles errors.
# If the git command returns a non-zero exit code, this function will call
# message(FATAL_ERROR) with detailed error information.
#
# Arguments:
#   <error_context>     - A descriptive string for error messages (e.g., "git init")
#   COMMAND             - The git command to execute (required)
#   WORKING_DIRECTORY   - Working directory for the command (required)
#   OUTPUT_VARIABLE     - Variable to store stdout (optional)
#   ERROR_VARIABLE      - Variable to store stderr (optional)
#
function(spm_git_execute_or_fail error_context)
    # Parse arguments
    cmake_parse_arguments(
        ARG
        ""
        "WORKING_DIRECTORY;OUTPUT_VARIABLE;ERROR_VARIABLE"
        "COMMAND"
        ${ARGN}
    )

    # Validate required arguments
    if(NOT DEFINED ARG_WORKING_DIRECTORY)
        message(FATAL_ERROR "spm_git_execute_or_fail: WORKING_DIRECTORY is required")
    endif()

    # Build execute_process arguments
    set(_exec_args COMMAND ${ARG_COMMAND})
    list(APPEND _exec_args WORKING_DIRECTORY "${ARG_WORKING_DIRECTORY}")

    # Always capture output and error for error messages
    list(APPEND _exec_args
        RESULT_VARIABLE _result
        OUTPUT_VARIABLE _output
        ERROR_VARIABLE _error
    )

    # Execute the command
    execute_process(${_exec_args})

    # Propagate variables to parent scope if requested
    if(DEFINED ARG_OUTPUT_VARIABLE)
        set(${ARG_OUTPUT_VARIABLE} "${_output}" PARENT_SCOPE)
    endif()
    if(DEFINED ARG_ERROR_VARIABLE)
        set(${ARG_ERROR_VARIABLE} "${_error}" PARENT_SCOPE)
    endif()

    # Check for failure
    if(NOT _result EQUAL 0)
        # Format command for error message
        string(REPLACE ";" " " _command_str "${ARG_COMMAND}")

        message(FATAL_ERROR
            "${error_context} failed\n"
            "  command: ${_command_str}\n"
            "  workdir: ${ARG_WORKING_DIRECTORY}\n"
            "  output : ${_output}\n"
            "  error  : ${_error}\n"
            "Exit code: ${_result}"
        )
    endif()
endfunction()

# spm_get_repo_cache_path(<repo_url> <out_var>)
#
# Computes the cache directory path for a given repository URL and stores
# the result in <out_var>.
#
# The cache path is constructed as:
#   <base_cache_dir>/repos/<SHA256_of_repo_url>
#
# Where <base_cache_dir> is determined by:
#   1. $ENV{SPM_GIT_CACHE_DIR} if set
#   2. Windows: %LOCALAPPDATA%/spm/git-cache
#   3. Unix: $XDG_CACHE_HOME/spm/git-cache (or ~/.cache/spm/git-cache)
#
function(spm_get_repo_cache_path repo_url out_var)
    # Determine base cache directory
    if(DEFINED ENV{SPM_GIT_CACHE_DIR})
        set(_base_cache_dir "$ENV{SPM_GIT_CACHE_DIR}")
    elseif(WIN32)
        set(_base_cache_dir "$ENV{LOCALAPPDATA}/spm/git-cache")
    else()
        if(DEFINED ENV{XDG_CACHE_HOME})
            set(_base_cache_dir "$ENV{XDG_CACHE_HOME}/spm/git-cache")
        else()
            set(_base_cache_dir "$ENV{HOME}/.cache/spm/git-cache")
        endif()
    endif()

    # Compute SHA256 hash of repo URL
    string(SHA256 _url_hash "${repo_url}")

    # Construct full cache path
    set(_cache_path "${_base_cache_dir}/repos/${_url_hash}")

    set(${out_var} "${_cache_path}" PARENT_SCOPE)
endfunction()

# spm_ensure_cache_repo_is_initialized(<repo_url> <cache_path>)
#
# Ensures that a bare git repository is initialized at <cache_path> with
# <repo_url> configured as the 'origin' remote.
#
# If <cache_path>/HEAD does not exist, this function will:
#   1. Initialize a bare git repository at <cache_path>
#   2. Add <repo_url> as the 'origin' remote
#
# If the repository already exists, this function does nothing.
#
function(spm_ensure_cache_repo_is_initialized repo_url cache_path)
    # Check if repository already exists by testing for HEAD file
    if(EXISTS "${cache_path}/HEAD")
        return()
    endif()

    # Initialize bare repository
    # Note: git init --bare creates the directory, so we use parent dir as working dir
    get_filename_component(_parent_dir "${cache_path}" DIRECTORY)
    get_filename_component(_dir_name "${cache_path}" NAME)

    # Ensure parent directory exists
    file(MAKE_DIRECTORY "${_parent_dir}")

    spm_git_execute_or_fail("spm_ensure_cache_repo_is_initialized(): git init --bare"
        COMMAND git init --bare "${_dir_name}"
        WORKING_DIRECTORY "${_parent_dir}"
    )

    # Add origin remote
    spm_git_execute_or_fail("spm_ensure_cache_repo_is_initialized(): git remote add origin"
        COMMAND git remote add origin "${repo_url}"
        WORKING_DIRECTORY "${cache_path}"
    )
endfunction()

# spm_ensure_cache_repo_has_commit(<cache_path> <commit_hash>)
#
# Ensures that <commit_hash> and all its associated trees and blobs are
# fully present in the cache repository at <cache_path>.
#
# The cache repository is typically bare, partial, and shallow. This function:
#   1. Checks if the commit and all objects are present using
#      'git rev-list --objects --missing=print'
#   2. If any objects are missing, fetches them using
#      'git fetch --no-filter origin <commit_hash>'
#
function(spm_ensure_cache_repo_has_commit cache_path commit_hash)
    # Check if the commit object itself is known
    execute_process(
        COMMAND git cat-file -e "${commit_hash}^{commit}"
        WORKING_DIRECTORY "${cache_path}"
        RESULT_VARIABLE _git_has_commit
        OUTPUT_QUIET
        ERROR_QUIET
    )

    if(_git_has_commit EQUAL 0)
        # Commit exists, check if all objects are present
        spm_git_execute_or_fail("spm_ensure_cache_repo_has_commit(): git rev-list"
            COMMAND git rev-list --objects --missing=print "${commit_hash}" --
            WORKING_DIRECTORY "${cache_path}"
            OUTPUT_VARIABLE _git_output
        )

        # Check if any objects are missing (lines starting with '?')
        string(REGEX MATCH "\\?" _has_missing "${_git_output}")

        if(NOT _has_missing)
            # Everything is present, early return
            return()
        endif()
    endif()

    # Fetch missing objects (either commit is missing or some objects are missing)
    spm_git_execute_or_fail("spm_ensure_cache_repo_has_commit(): git fetch"
        COMMAND git fetch --no-filter origin "${commit_hash}"
        WORKING_DIRECTORY "${cache_path}"
    )
endfunction()

# spm_git_is_ancestor(<repo_url> <hash-a> <hash-b> <out-var>)
#
# Checks whether commit <hash-a> is an ancestor of <hash-b> in the repository
# identified by <repo_url>. Writes the result ("TRUE"/"FALSE") to <out-var>.
#
# To avoid repeated git calls, results are memoized using INTERNAL
# cache variables named:
#
#   SPM_GIT_IS_ANCESTOR_<HASH_A>_<HASH_B>
#
# This is valid because:
#   * Commit hashes (SHA-1/SHA-256) uniquely identify commit DAG nodes.
#   * For fixed hashes, the ancestor relation is fully determined by the DAG.
#   * If two repositories share the same pair of commit hashes, the relation
#     between them is the same (ignoring cryptographic collisions).
#
# Using CACHE INTERNAL keeps these entries out of cmake-gui/ccmake and
# `cmake -L`, but still persists them across configure runs. Since the DAG
# never changes for a given commit hash, the cached result never goes stale.
#
# This function uses the git cache repository for efficient operation.
#
function(spm_git_is_ancestor repo_url hash_a hash_b out_var)
    set(_cache_key "SPM_GIT_IS_ANCESTOR_${hash_a}_${hash_b}")

    # Early out: check if result is already cached
    if(DEFINED ${_cache_key})
        set(${out_var} "${${_cache_key}}" PARENT_SCOPE)
        return()
    endif()

    # Get and initialize cache repository
    spm_get_repo_cache_path("${repo_url}" _cache_path)
    spm_ensure_cache_repo_is_initialized("${repo_url}" "${_cache_path}")

    execute_process(
        COMMAND git merge-base --is-ancestor "${hash_a}" "${hash_b}"
        WORKING_DIRECTORY "${_cache_path}"
        RESULT_VARIABLE _git_result
        OUTPUT_QUIET
        ERROR_QUIET
    )

    if(_git_result EQUAL 0)
        set(_value TRUE)
    elseif(_git_result EQUAL 1)
        set(_value FALSE)
    else()
        # Non-0/1 result might indicate missing commits in cache repo
        # Fetch the commits using tree:0 filter for performance
        spm_git_execute_or_fail("spm_git_is_ancestor(): git fetch"
            COMMAND git fetch --filter=tree:0 origin "${hash_a}" "${hash_b}"
            WORKING_DIRECTORY "${_cache_path}"
        )

        # Retry the ancestor check
        execute_process(
            COMMAND git merge-base --is-ancestor "${hash_a}" "${hash_b}"
            WORKING_DIRECTORY "${_cache_path}"
            RESULT_VARIABLE _git_result
            OUTPUT_QUIET
            ERROR_QUIET
        )

        if(_git_result EQUAL 0)
            set(_value TRUE)
        elseif(_git_result EQUAL 1)
            set(_value FALSE)
        else()
            message(FATAL_ERROR
                "spm_git_is_ancestor(): git merge-base failed\n"
                "  repo_url   : ${repo_url}\n"
                "  cache_path : ${_cache_path}\n"
                "  A          : ${hash_a}\n"
                "  B          : ${hash_b}\n"
                "Exit code: ${_git_result}"
            )
        endif()
    endif()

    set(${_cache_key} "${_value}" CACHE INTERNAL
        "Whether ${hash_a} is an ancestor of ${hash_b}"
    )

    set(${out_var} "${_value}" PARENT_SCOPE)
endfunction()

# spm_git_restore_worktree_to(<cache_path> <commit_hash> <target_dir>)
#
# Restores files from <commit_hash> in the bare repository at <cache_path>
# into <target_dir>, effectively populating a work tree without cloning.
#
# This uses: git --git-dir=<cache_path> --work-tree=<target_dir> restore --source=<commit_hash> .
#
# IMPORTANT NOTES:
#   * The commit must be fully present in the cache repository. Use
#     spm_ensure_cache_repo_has_commit() before calling this function if unsure.
#   * The cache_path is typically obtained using spm_get_repo_cache_path().
#   * This function will NOT clean the target directory and will override existing
#     files. We do this to prevent data loss for now (might change in the future).
#
function(spm_git_restore_worktree_to cache_path commit_hash target_dir)
    spm_git_execute_or_fail("spm_git_restore_worktree_to(): git restore"
        COMMAND git --work-tree="${target_dir}" restore --source="${commit_hash}" .
        WORKING_DIRECTORY "${cache_path}"
    )
endfunction()

# spm_git_checkout_full_repo_at(<cache_path> <repo_url> <commit_hash> <target_dir>)
#
# Creates or updates a full git repository at <target_dir> and checks out
# <commit_hash> in detached HEAD state. The commit is fetched from the cache
# repository instead of the remote origin.
#
# This function performs the following steps:
#   1. Initialize git repository at <target_dir> (skipped if already exists)
#   2. Add <cache_path> as the 'cache' remote (skipped if already exists)
#   3. Add <repo_url> as the 'origin' remote (skipped if already exists)
#   4. Fetch <commit_hash> from the 'cache' remote (not from origin)
#   5. Checkout <commit_hash> in detached HEAD state
#
# IMPORTANT: If <target_dir> already contains a git repository, this function
# assumes the 'cache' and 'origin' remotes are already correctly configured.
# Only when initializing a new repository will the remotes be set up.
#
function(spm_git_checkout_full_repo_at cache_path repo_url commit_hash target_dir)
    # Initialize repository if it doesn't exist
    if(NOT EXISTS "${target_dir}/.git")
        spm_git_execute_or_fail("spm_git_checkout_full_repo_at(): git init"
            COMMAND git init
            WORKING_DIRECTORY "${target_dir}"
        )

        # Add origin remote
        spm_git_execute_or_fail("spm_git_checkout_full_repo_at(): git remote add origin"
            COMMAND git remote add origin "${repo_url}"
            WORKING_DIRECTORY "${target_dir}"
        )
    endif()

    # Add cache remote if it doesn't exist
    execute_process(
        COMMAND git remote get-url cache
        WORKING_DIRECTORY "${target_dir}"
        RESULT_VARIABLE _has_cache_remote
        OUTPUT_QUIET
        ERROR_QUIET
    )
    if(NOT _has_cache_remote EQUAL 0)
        spm_git_execute_or_fail("spm_git_checkout_full_repo_at(): git remote add cache"
            COMMAND git remote add cache "${cache_path}"
            WORKING_DIRECTORY "${target_dir}"
        )
    endif()

    # Fetch commit from cache remote
    spm_git_execute_or_fail("spm_git_checkout_full_repo_at(): git fetch"
        COMMAND git fetch cache "${commit_hash}"
        WORKING_DIRECTORY "${target_dir}"
    )

    # Checkout commit in detached HEAD state
    spm_git_execute_or_fail("spm_git_checkout_full_repo_at(): git checkout"
        COMMAND git checkout --detach "${commit_hash}"
        WORKING_DIRECTORY "${target_dir}"
    )
endfunction()

# spm_git_is_dirty(<repo_path> <out_var>)
#
# Checks whether the git repository at <repo_path> has uncommitted changes
# in the working directory or index. Writes the result ("TRUE"/"FALSE")
# to <out_var>.
#
# This uses 'git diff-index --quiet HEAD --' which checks for any differences
# between the index and HEAD. The exit codes are:
#   0 => repository is clean (no uncommitted changes)
#   1 => repository is dirty (has uncommitted changes)
#   other => error (e.g., not a git repository, no HEAD exists)
#
function(spm_git_is_dirty repo_path out_var)
    execute_process(
        COMMAND git diff-index --quiet HEAD --
        WORKING_DIRECTORY "${repo_path}"
        RESULT_VARIABLE _git_result
        OUTPUT_QUIET
        ERROR_QUIET
    )

    if(_git_result EQUAL 0)
        set(_is_dirty FALSE)
    elseif(_git_result EQUAL 1)
        set(_is_dirty TRUE)
    else()
        message(FATAL_ERROR
            "spm_git_is_dirty(): git diff-index failed\n"
            "  repo_path: ${repo_path}\n"
            "Exit code: ${_git_result}"
        )
    endif()

    set(${out_var} "${_is_dirty}" PARENT_SCOPE)
endfunction()

