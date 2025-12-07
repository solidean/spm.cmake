# spm_finalize()
#
# Call this at the end of packages.cmake after all spm_package() calls.
# It validates that all spm_require() constraints are satisfied by the
# declared packages.
#
# For each requirement with a MIN_COMMIT, this function checks that MIN_COMMIT
# is an ancestor of the COMMIT specified in the corresponding spm_package().
# This ensures that all libraries get at least the commit they need.
#
# Requirements:
# - All packages must be declared via spm_package() before spm_finalize().
# - Ancestry checks are performed using the git cache repository.
#
function(spm_finalize)
    # Get all registered requirements
    get_property(_spm_requirements GLOBAL PROPERTY SPM_REQUIREMENTS)

    foreach(_req IN LISTS _spm_requirements)
        # Parse the record: "origin|name|git_url|min_commit"
        string(REPLACE "|" ";" _req_parts "${_req}")
        list(LENGTH _req_parts _req_len)

        if(NOT _req_len EQUAL 4)
            message(WARNING "SPM: malformed requirement record: ${_req}")
            continue()
        endif()

        list(GET _req_parts 0 _req_origin)
        list(GET _req_parts 1 _req_name)
        list(GET _req_parts 2 _req_git_url)
        list(GET _req_parts 3 _req_min_commit)

        # Skip if no MIN_COMMIT specified
        if(NOT _req_min_commit)
            continue()
        endif()

        # Normalize the package name to find the corresponding spm_package vars
        spm_normalize_name("${_req_name}" _req_name_norm)

        # Check if package was declared
        if(NOT DEFINED "SPM_PKG_${_req_name_norm}_COMMIT")
            message(FATAL_ERROR
                "SPM: requirement from '${_req_origin}' needs package '${_req_name}', "
                "but no spm_package(NAME ${_req_name} ...) was declared.")
        endif()

        set(_pkg_commit "${SPM_PKG_${_req_name_norm}_COMMIT}")
        set(_pkg_git_url "${SPM_PKG_${_req_name_norm}_GIT_URL}")

        # Check: is MIN_COMMIT an ancestor of the package's COMMIT?
        # spm_git_is_ancestor handles cache initialization internally
        spm_git_is_ancestor(
            "${_pkg_git_url}"
            "${_req_min_commit}"
            "${_pkg_commit}"
            _is_ancestor
        )

        if(NOT _is_ancestor)
            message(FATAL_ERROR
                "SPM: version constraint violated for package '${_req_name}'.\n"
                "  Required by: ${_req_origin}\n"
                "  MIN_COMMIT:  ${_req_min_commit}\n"
                "  Provided:    ${_pkg_commit}\n"
                "The provided commit is not a descendant of the required minimum.\n"
                "Update the COMMIT in spm_package(NAME ${_req_name} ...) to a newer version.")
        endif()
    endforeach()
endfunction()
