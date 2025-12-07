# spm_package
#
# Usage:
#   spm_package(
#       NAME    clean-core
#       GIT_URL https://github.com/project-arcana/clean-core.git
#       COMMIT  dfc52ee09fe3da37638d8d7d0c6176c59a367562
#       [CHECKOUT NESTED|VENDORED]
#       [UPDATE_REF <branch>]
#       [NO_ADD_SUBDIRECTORY]
#   )
#
# Design:
# - Each package lives in "${SPM_EXTERN_DIR}/${NAME}" (defaults to "${CMAKE_SOURCE_DIR}/extern").
# - A ".spm-meta.cmake" file in that directory records the realized COMMIT and CHECKOUT mode.
#   This lives *with the checkout*, so it is shared across build dirs and tools.
# - The "happy path" is fast: if the directory exists and meta matches the requested commit/mode,
#   we do no git calls, only cheap filesystem/meta checks.
# - Auto-update:
#   * If COMMIT changes (for NESTED mode) and both SPM_AUTO_UPDATE and
#     SPM_PKG_<PKG>_AUTO_UPDATE are ON, the package is re-realized.
#   * NESTED: if the repo is dirty, a warning is issued but configure continues
#     without updating (to avoid data loss).
#   * VENDORED: auto-update is not supported; switching requires the SPM CLI.
# - Checkout modes:
#   * NESTED (default): full git checkout (nested repo) populated from a local git cache.
#                       Uses spm_get_repo_cache_path and related helpers to minimize network I/O.
#                       Auto-update only if repo is clean.
#   * VENDORED: snapshot without .git, contents become part of the main repo history.
#               Switching from NESTED to VENDORED requires the SPM CLI.
#               Once VENDORED, the package is managed manually.
# - Names:
#   * NAME must match ^[A-Za-z0-9_.-]+$.
#   * Normalized name = uppercase, '-' and '.' replaced by '_'.
#   * There must not be two packages with the same normalized name
#     (e.g. clean-core and CLEAN_CORE); that's a hard error.
# - Control & speed:
#   * Global toggle: SPM_AUTO_UPDATE (CACHE BOOL, default ON).
#   * Per-package toggle: SPM_PKG_<PKG>_AUTO_UPDATE (CACHE BOOL, default ON).
#   * Non-cache vars record requested state:
#       SPM_PKG_<PKG>_GIT_URL
#       SPM_PKG_<PKG>_COMMIT
#       SPM_PKG_<PKG>_CHECKOUT
#       SPM_PKG_<PKG>_DIR
#   * Optional NO_ADD_SUBDIRECTORY lets you control when/if the package
#     is wired into the CMake target graph.
#
function(spm_package)
    if(NOT SPM_ENABLED)
        set(SPM_ENABLED ON CACHE INTERNAL "SPM is enabled (set by spm_package)")
    endif()

    set(options NO_ADD_SUBDIRECTORY)
    set(oneValueArgs NAME GIT_URL COMMIT CHECKOUT UPDATE_REF)
    cmake_parse_arguments(SPM "${options}" "${oneValueArgs}" "" ${ARGN})

    if(NOT SPM_NAME)
        message(FATAL_ERROR "spm_package: NAME is required")
    endif()
    if(NOT SPM_GIT_URL)
        message(FATAL_ERROR "spm_package(${SPM_NAME}): GIT_URL is required")
    endif()
    if(NOT SPM_COMMIT)
        message(FATAL_ERROR "spm_package(${SPM_NAME}): COMMIT is required")
    endif()

    # Validate name
    if(NOT SPM_NAME MATCHES "^[A-Za-z0-9_.-]+$")
        message(FATAL_ERROR
            "spm_package: NAME '${SPM_NAME}' is invalid. "
            "Allowed: [A-Za-z0-9_.-]+")
    endif()

    # Normalize name for use as CMake identifier
    spm_normalize_name("${SPM_NAME}" SPM_NAME_NORM)

    # Enforce uniqueness of normalized names
    if(DEFINED "SPM_PKG_${SPM_NAME_NORM}_NAME")
        message(FATAL_ERROR
            "spm_package: package '${SPM_NAME}' is being declared again. "
            "The normalized identifier '${SPM_NAME_NORM}' is already used by "
            "package '${SPM_PKG_${SPM_NAME_NORM}_NAME}'. "
            "Each package name must be unique once normalized (uppercase, '-' and '.' → '_').")
    endif()

    # Extern root (default)
    if(NOT DEFINED SPM_EXTERN_DIR)
        set(SPM_EXTERN_DIR "${CMAKE_SOURCE_DIR}/extern")
    endif()
    file(MAKE_DIRECTORY "${SPM_EXTERN_DIR}")

    # Checkout mode: default NESTED; CHECKOUT argument can override.
    set(_spm_checkout_mode "NESTED")
    if(SPM_CHECKOUT)
        string(TOUPPER "${SPM_CHECKOUT}" _spm_checkout_mode)
    endif()
    set(_spm_valid_modes "NESTED" "VENDORED")
    list(FIND _spm_valid_modes "${_spm_checkout_mode}" _spm_mode_idx)
    if(_spm_mode_idx EQUAL -1)
        message(FATAL_ERROR
            "spm_package(${SPM_NAME}): invalid CHECKOUT='${SPM_CHECKOUT}'. "
            "Allowed: NESTED, VENDORED.")
    endif()

    # Global auto-update toggle
    if(NOT DEFINED SPM_AUTO_UPDATE)
        set(SPM_AUTO_UPDATE ON CACHE BOOL
            "Auto-update SPM packages when COMMIT/CHECKOUT changes")
    endif()

    # Per-package auto-update toggle
    set(_spm_pkg_auto_var "SPM_PKG_${SPM_NAME_NORM}_AUTO_UPDATE")
    if(NOT DEFINED ${_spm_pkg_auto_var})
        set(${_spm_pkg_auto_var} ON CACHE BOOL
            "Auto-update SPM package ${SPM_NAME} when COMMIT/CHECKOUT changes")
    endif()

    # Record requested state in non-cache vars (global for spm_finalize and other spm_package invocations)
    set("SPM_PKG_${SPM_NAME_NORM}_NAME" "${SPM_NAME}" PARENT_SCOPE)
    set("SPM_PKG_${SPM_NAME_NORM}_GIT_URL" "${SPM_GIT_URL}" PARENT_SCOPE)
    set("SPM_PKG_${SPM_NAME_NORM}_COMMIT" "${SPM_COMMIT}" PARENT_SCOPE)
    set("SPM_PKG_${SPM_NAME_NORM}_CHECKOUT" "${_spm_checkout_mode}" PARENT_SCOPE)

    # Package directory + meta
    set(_spm_pkg_dir "${SPM_EXTERN_DIR}/${SPM_NAME}")
    set(_spm_meta "${_spm_pkg_dir}/.spm-meta.cmake")
    set("SPM_PKG_${SPM_NAME_NORM}_DIR" "${_spm_pkg_dir}" PARENT_SCOPE)

    # Read meta if present
    set(_spm_have_dir FALSE)
    set(_spm_have_meta FALSE)
    set(_spm_meta_commit "")
    set(_spm_meta_mode "")
    if(EXISTS "${_spm_pkg_dir}")
        set(_spm_have_dir TRUE)
    endif()
    if(EXISTS "${_spm_meta}")
        set(_spm_have_meta TRUE)
        # Clear old values then include
        unset(SPM_META_COMMIT)
        unset(SPM_META_CHECKOUT)
        include("${_spm_meta}")
        if(DEFINED SPM_META_COMMIT)
            set(_spm_meta_commit "${SPM_META_COMMIT}")
        endif()
        if(DEFINED SPM_META_CHECKOUT)
            set(_spm_meta_mode "${SPM_META_CHECKOUT}")
        endif()
    endif()

    # Decide whether we need to (re)realize the package
    set(_spm_need_checkout FALSE)
    if(NOT _spm_have_dir)
        set(_spm_need_checkout TRUE)
    else()
        # Determine if we need to re-checkout based on the new model:
        # - NESTED→NESTED: only if commit changed
        # - NESTED→VENDORED: skip (requires CLI)
        # - VENDORED→NESTED: skip if no .spm-meta.cmake (means it was manually vendored)
        # - VENDORED→VENDORED: never (manual management)

        if(_spm_checkout_mode STREQUAL "NESTED")
            if(_spm_have_meta)
                # Previous checkout was NESTED (has meta)
                if(NOT _spm_meta_commit STREQUAL "${SPM_COMMIT}")
                    set(_spm_need_checkout TRUE)
                endif()
            else()
                # No meta: assume manually vendored, do not touch
                message(STATUS
                    "SPM: package '${SPM_NAME}' exists in '${_spm_pkg_dir}' "
                    "without .spm-meta.cmake; assuming manually vendored. "
                    "Switching back to NESTED checkout requires the SPM CLI.")
            endif()
        elseif(_spm_checkout_mode STREQUAL "VENDORED")
            # Current mode is VENDORED
            if(_spm_have_meta)
                # Previous checkout was NESTED; warn that CLI is required
                message(WARNING
                    "SPM: package '${SPM_NAME}' was previously NESTED (has .spm-meta.cmake) "
                    "but is now requested as VENDORED. Switching from NESTED to VENDORED "
                    "requires the SPM CLI to ensure proper user intent. Skipping update.")
            endif()
            # VENDORED packages are never auto-updated
        endif()
    endif()

    # Check auto-update settings
    set(_spm_auto_allowed FALSE)
    if(SPM_AUTO_UPDATE)
        if(${_spm_pkg_auto_var})
            set(_spm_auto_allowed TRUE)
        endif()
    endif()

    if(_spm_need_checkout AND NOT _spm_auto_allowed AND _spm_have_dir)
        message(STATUS
            "SPM: package '${SPM_NAME}' is out-of-date "
            "(have commit '${_spm_meta_commit}', mode '${_spm_meta_mode}'; "
            "want commit '${SPM_COMMIT}', mode '${_spm_checkout_mode}'), "
            "but auto-update is disabled (SPM_AUTO_UPDATE and/or "
            "${_spm_pkg_auto_var} are OFF). Keeping existing checkout.")
        set(_spm_need_checkout FALSE)
    endif()

    # Realize / update package
    if(_spm_need_checkout)
        # NESTED checkout mode
        if(_spm_checkout_mode STREQUAL "NESTED")
            # Check if directory exists without .git (indicates it was vendored before)
            if(_spm_have_dir AND NOT EXISTS "${_spm_pkg_dir}/.git")
                # Special case: spm.cmake itself during bootstrap doesn't have .spm-meta.cmake
                set(_is_spm_cmake_bootstrap FALSE)
                if(SPM_NAME STREQUAL "spm.cmake" AND NOT _spm_have_meta)
                    set(_is_spm_cmake_bootstrap TRUE)
                endif()

                if(NOT _is_spm_cmake_bootstrap)
                    message(WARNING
                        "SPM: package '${SPM_NAME}' exists in '${_spm_pkg_dir}' "
                        "without .git directory. This indicates it was previously VENDORED. "
                        "Switching back to NESTED checkout requires the SPM CLI. Skipping update.")
                    set(_spm_need_checkout FALSE)
                endif()
            endif()

            if(_spm_need_checkout)
                # Get repo cache directory
                spm_get_repo_cache_path("${SPM_GIT_URL}" _spm_cache_path)

                # Ensure cache repo is initialized
                spm_ensure_cache_repo_is_initialized("${SPM_GIT_URL}" "${_spm_cache_path}")

                # Ensure cache has the target commit
                spm_ensure_cache_repo_has_commit("${_spm_cache_path}" "${SPM_COMMIT}")

                # Check if the target directory is dirty (if it exists with .git)
                if(_spm_have_dir AND EXISTS "${_spm_pkg_dir}/.git")
                    spm_git_is_dirty("${_spm_pkg_dir}" _spm_is_dirty)
                    if(_spm_is_dirty)
                        message(WARNING
                            "SPM: package '${SPM_NAME}' at '${_spm_pkg_dir}' has uncommitted changes. "
                            "Skipping checkout to avoid data loss. Configure will continue with current state. "
                            "Commit/stash your changes or set ${_spm_pkg_auto_var}=OFF to suppress this warning.")
                        set(_spm_need_checkout FALSE)
                    endif()
                endif()

                if(_spm_need_checkout)
                    # Create directory if it doesn't exist
                    if(NOT _spm_have_dir)
                        file(MAKE_DIRECTORY "${_spm_pkg_dir}")
                    endif()

                    # Checkout from cache
                    spm_git_checkout_full_repo_at("${_spm_cache_path}" "${SPM_GIT_URL}" "${SPM_COMMIT}" "${_spm_pkg_dir}")

                    # Write meta file for the realized state
                    file(WRITE "${_spm_meta}"
                        "set(SPM_META_NAME \"${SPM_NAME}\")\n"
                        "set(SPM_META_GIT_URL \"${SPM_GIT_URL}\")\n"
                        "set(SPM_META_COMMIT \"${SPM_COMMIT}\")\n"
                        "set(SPM_META_CHECKOUT \"${_spm_checkout_mode}\")\n"
                    )
                endif()
            endif()
        endif()
        # VENDORED mode: we've already handled this above (never auto-update)
    endif()

    # Wire into the build, unless explicitly suppressed
    if(NOT SPM_NO_ADD_SUBDIRECTORY)
        if(NOT EXISTS "${_spm_pkg_dir}/CMakeLists.txt")
            message(FATAL_ERROR
                "SPM: package '${SPM_NAME}' in '${_spm_pkg_dir}' has no "
                "CMakeLists.txt; cannot add_subdirectory.")
        endif()
        add_subdirectory("${_spm_pkg_dir}")
    endif()
endfunction()
