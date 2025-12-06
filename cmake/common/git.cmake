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
    execute_process(
        COMMAND git init --bare "${cache_path}"
        RESULT_VARIABLE _git_result
        OUTPUT_VARIABLE _git_output
        ERROR_VARIABLE _git_error
    )

    if(NOT _git_result EQUAL 0)
        message(FATAL_ERROR
            "spm_ensure_cache_repo_is_initialized(): git init failed\n"
            "  path  : ${cache_path}\n"
            "  output: ${_git_output}\n"
            "  error : ${_git_error}\n"
            "Exit code: ${_git_result}"
        )
    endif()

    # Add origin remote
    execute_process(
        COMMAND git remote add origin "${repo_url}"
        WORKING_DIRECTORY "${cache_path}"
        RESULT_VARIABLE _git_result
        OUTPUT_VARIABLE _git_output
        ERROR_VARIABLE _git_error
    )

    if(NOT _git_result EQUAL 0)
        message(FATAL_ERROR
            "spm_ensure_cache_repo_is_initialized(): git remote add failed\n"
            "  repo  : ${repo_url}\n"
            "  path  : ${cache_path}\n"
            "  output: ${_git_output}\n"
            "  error : ${_git_error}\n"
            "Exit code: ${_git_result}"
        )
    endif()
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
    # Check for missing objects
    execute_process(
        COMMAND git rev-list --objects --missing=print "${commit_hash}" --
        WORKING_DIRECTORY "${cache_path}"
        RESULT_VARIABLE _git_result
        OUTPUT_VARIABLE _git_output
        ERROR_VARIABLE _git_error
    )

    if(NOT _git_result EQUAL 0)
        message(FATAL_ERROR
            "spm_ensure_cache_repo_has_commit(): git rev-list failed\n"
            "  path  : ${cache_path}\n"
            "  commit: ${commit_hash}\n"
            "  output: ${_git_output}\n"
            "  error : ${_git_error}\n"
            "Exit code: ${_git_result}"
        )
    endif()

    # Check if any objects are missing (lines starting with '?')
    string(REGEX MATCH "\\?" _has_missing "${_git_output}")

    if(_has_missing)
        # Fetch missing objects
        execute_process(
            COMMAND git fetch --no-filter origin "${commit_hash}"
            WORKING_DIRECTORY "${cache_path}"
            RESULT_VARIABLE _git_result
            OUTPUT_VARIABLE _git_output
            ERROR_VARIABLE _git_error
        )

        if(NOT _git_result EQUAL 0)
            message(FATAL_ERROR
                "spm_ensure_cache_repo_has_commit(): git fetch failed\n"
                "  path  : ${cache_path}\n"
                "  commit: ${commit_hash}\n"
                "  output: ${_git_output}\n"
                "  error : ${_git_error}\n"
                "Exit code: ${_git_result}"
            )
        endif()
    endif()
endfunction()

# spm_git_is_ancestor(<cache_path> <hash-a> <hash-b> <out-var>)
#
# Checks whether commit <hash-a> is an ancestor of <hash-b> inside the
# repository located at <cache_path>. Writes the result ("TRUE"/"FALSE")
# to <out-var>.
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
function(spm_git_is_ancestor cache_path hash_a hash_b out_var)
    set(_cache_key "SPM_GIT_IS_ANCESTOR_${hash_a}_${hash_b}")

    if(DEFINED ${_cache_key})
        set(${out_var} "${${_cache_key}}" PARENT_SCOPE)
        return()
    endif()

    execute_process(
        COMMAND git merge-base --is-ancestor "${hash_a}" "${hash_b}"
        WORKING_DIRECTORY "${cache_path}"
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
        # Try fetching the commits and retry once
        execute_process(
            COMMAND git fetch --filter=tree:0 origin "${hash_a}" "${hash_b}"
            WORKING_DIRECTORY "${cache_path}"
            RESULT_VARIABLE _fetch_result
            OUTPUT_QUIET
            ERROR_QUIET
        )

        # Retry the ancestor check
        execute_process(
            COMMAND git merge-base --is-ancestor "${hash_a}" "${hash_b}"
            WORKING_DIRECTORY "${cache_path}"
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
                "spm_git_is_ancestor(): git failed for\n"
                "  cache_path : ${cache_path}\n"
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

