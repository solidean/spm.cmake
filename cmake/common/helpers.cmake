# spm_normalize_name(<name> <out-var>)
#
# Normalizes a package name for use as a CMake identifier:
#   - Converts to uppercase
#   - Replaces '-' and '.' with '_'
#
# Example: "clean-core" -> "CLEAN_CORE"
#          "foo.bar"    -> "FOO_BAR"
#
function(spm_normalize_name name out_var)
    string(TOUPPER "${name}" _normalized)
    string(REPLACE "-" "_" _normalized "${_normalized}")
    string(REPLACE "." "_" _normalized "${_normalized}")
    set(${out_var} "${_normalized}" PARENT_SCOPE)
endfunction()

# spm_git_is_ancestor(<repo_path> <hash-a> <hash-b> <out-var>)
#
# Checks whether commit <hash-a> is an ancestor of <hash-b> inside the
# repository located at <repo_path>. Writes the result ("TRUE"/"FALSE")
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
function(spm_git_is_ancestor repo_path hash_a hash_b out_var)
    set(_cache_key "SPM_GIT_IS_ANCESTOR_${hash_a}_${hash_b}")

    if(DEFINED ${_cache_key})
        set(${out_var} "${${_cache_key}}" PARENT_SCOPE)
        return()
    endif()

    execute_process(
        COMMAND git merge-base --is-ancestor "${hash_a}" "${hash_b}"
        WORKING_DIRECTORY "${repo_path}"
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
            "  repo : ${repo_path}\n"
            "  A    : ${hash_a}\n"
            "  B    : ${hash_b}\n"
            "Exit code: ${_git_result}"
        )
    endif()

    set(${_cache_key} "${_value}" CACHE INTERNAL
        "Whether ${hash_a} is an ancestor of ${hash_b}"
    )

    set(${out_var} "${_value}" PARENT_SCOPE)
endfunction()
