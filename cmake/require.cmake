# spm_require(NAME <name> [GIT_URL <url>] [MIN_COMMIT <sha>])
#
# Declares that *this library* depends on <pkg> and requires at least commit <sha>.
# These calls do not fetch anything; they only register constraints for the root
# application to validate against its spm_package() declarations.
#
# Rationale:
# Libraries should not decide where dependencies come from or which commit the
# build uses. The root application owns the full dependency mapping. Libraries
# merely describe “I need <pkg>, and it must include commit <sha>” so that the
# app can choose a specific commit that satisfies all minimums.
#
# The GIT_URL here acts primarily as structured documentation: it’s the canonical
# place to look when adding a missing package, and lets tooling pre-fill URLs.
# In normal usage, the root app’s spm_package() overrides the location entirely.
#
# The MIN_COMMIT expresses a true ancestry constraint: the final chosen commit
# must be a descendant of MIN_COMMIT (`git merge-base --is-ancestor`). It
# reflects the point in history where this library gained a needed feature or fix.
# The check is a sanity guard, not a version solver.
function(spm_require)
    set(_options)
    set(_oneValueArgs NAME GIT_URL MIN_COMMIT)
    set(_multiValueArgs)

    cmake_parse_arguments(
        SPM_REQ
        "${_options}"
        "${_oneValueArgs}"
        "${_multiValueArgs}"
        ${ARGN}
    )

    if(NOT SPM_REQ_NAME)
        message(FATAL_ERROR "spm_require: NAME is required")
    endif()

    # Derive a readable origin: path of the calling CMakeLists relative to the root
    get_filename_component(
        _spm_origin
        "${CMAKE_CURRENT_LIST_FILE}"
        RELATIVE "${CMAKE_SOURCE_DIR}"
    )

    # Normalize possibly-empty fields to avoid stray semicolons breaking the list
    set(_spm_name "${SPM_REQ_NAME}")
    set(_spm_git_url "${SPM_REQ_GIT_URL}")
    set(_spm_min_commit "${SPM_REQ_MIN_COMMIT}")

    # Encode as a single string; '|' is a safe separator for typical URLs/SHAs
    set(_spm_record
        "${_spm_origin}|${_spm_name}|${_spm_git_url}|${_spm_min_commit}"
    )

    # Append to global list of requirements
    set_property(GLOBAL APPEND PROPERTY SPM_REQUIREMENTS "${_spm_record}")
endfunction()
