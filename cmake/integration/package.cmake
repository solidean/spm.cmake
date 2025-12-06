# spm_package
#
# Usage:
#   spm_package(
#       NAME    clean-core
#       GIT_URL https://github.com/project-arcana/clean-core.git
#       COMMIT  dfc52ee09fe3da37638d8d7d0c6176c59a367562
#       [CHECKOUT WORKTREE|FULL|VENDORED]
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
#   * If COMMIT or CHECKOUT changes and both SPM_AUTO_UPDATE and
#     SPM_PKG_<PKG>_AUTO_UPDATE are ON, the package is re-realized.
#   * WORKTREE/VENDORED: local changes are overwritten on update.
#   * FULL: if the repo is dirty, auto-update fails with FATAL_ERROR to avoid
#     destroying local work.
# - Checkout modes:
#   * WORKTREE (default): snapshot of the tree at COMMIT, no .git directory.
#                         A .gitignore '*' is written so nothing under the package
#                         is picked up by the outer git.
#   * FULL: full git checkout (nested repo). .git is kept, but .gitignore '*' is also written so outer git ignores it. 
#           Auto-update refuses to touch a dirty repo.
#   * VENDORED: snapshot without .git and without .gitignore '*', so the package
#               contents become part of the main repo history (“vendored” code).
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

    # Checkout mode: default WORKTREE; CHECKOUT argument can override.
    set(_spm_checkout_mode "WORKTREE")
    if(SPM_CHECKOUT)
        string(TOUPPER "${SPM_CHECKOUT}" _spm_checkout_mode)
    endif()
    if(NOT _spm_checkout_mode IN_LIST _spm_valid_modes)
        set(_spm_valid_modes "WORKTREE" "FULL" "VENDORED")
    endif()
    list(FIND _spm_valid_modes "${_spm_checkout_mode}" _spm_mode_idx)
    if(_spm_mode_idx EQUAL -1)
        message(FATAL_ERROR
            "spm_package(${SPM_NAME}): invalid CHECKOUT='${SPM_CHECKOUT}'. "
            "Allowed: WORKTREE, FULL, VENDORED.")
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

    # Record requested state in non-cache vars
    set("SPM_PKG_${SPM_NAME_NORM}_NAME" "${SPM_NAME}")
    set("SPM_PKG_${SPM_NAME_NORM}_GIT_URL" "${SPM_GIT_URL}")
    set("SPM_PKG_${SPM_NAME_NORM}_COMMIT" "${SPM_COMMIT}")
    set("SPM_PKG_${SPM_NAME_NORM}_CHECKOUT" "${_spm_checkout_mode}")

    # Package directory + meta
    set(_spm_pkg_dir "${SPM_EXTERN_DIR}/${SPM_NAME}")
    set(_spm_meta "${_spm_pkg_dir}/.spm-meta.cmake")
    set("SPM_PKG_${SPM_NAME_NORM}_DIR" "${_spm_pkg_dir}")

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
    set(_spm_need_fetch FALSE)
    if(NOT _spm_have_dir)
        set(_spm_need_fetch TRUE)
    else()
        if(_spm_have_meta)
            if(NOT _spm_meta_commit STREQUAL "${SPM_COMMIT}"
                OR NOT _spm_meta_mode STREQUAL "${_spm_checkout_mode}")
                set(_spm_need_fetch TRUE)
            endif()
        else()
            # Directory exists but no meta: treat as manually managed, do not touch.
            message(STATUS
                "SPM: package '${SPM_NAME}' already exists in '${_spm_pkg_dir}' "
                "without .spm-meta.cmake; leaving as-is (no auto-update).")
        endif()
    endif()

    # Check auto-update settings
    set(_spm_auto_allowed FALSE)
    if(SPM_AUTO_UPDATE)
        if(${_spm_pkg_auto_var})
            set(_spm_auto_allowed TRUE)
        endif()
    endif()

    if(_spm_need_fetch AND NOT _spm_auto_allowed AND _spm_have_dir)
        message(STATUS
            "SPM: package '${SPM_NAME}' is out-of-date "
            "(have commit '${_spm_meta_commit}', mode '${_spm_meta_mode}'; "
            "want commit '${SPM_COMMIT}', mode '${_spm_checkout_mode}'), "
            "but auto-update is disabled (SPM_AUTO_UPDATE and/or "
            "${_spm_pkg_auto_var} are OFF). Keeping existing checkout.")
        set(_spm_need_fetch FALSE)
    endif()

    # Realize / update package
    if(_spm_need_fetch)
        if(_spm_have_dir AND NOT _spm_have_meta)
            # Conservative: don't touch a foreign directory
            message(FATAL_ERROR
                "SPM: refusing to modify existing directory '${_spm_pkg_dir}' "
                "for package '${SPM_NAME}' because it lacks .spm-meta.cmake. "
                "Remove the directory or add meta manually.")
        endif()

        # FULL: if repo exists and is dirty, refuse to auto-update.
        if(_spm_checkout_mode STREQUAL "FULL"
            AND _spm_have_dir
            AND EXISTS "${_spm_pkg_dir}/.git")
            execute_process(
                COMMAND git -C "${_spm_pkg_dir}" status --porcelain
                OUTPUT_VARIABLE _spm_git_status
                OUTPUT_STRIP_TRAILING_WHITESPACE
            )
            if(NOT "${_spm_git_status}" STREQUAL "")
                message(FATAL_ERROR
                    "SPM: cannot auto-update FULL checkout for '${SPM_NAME}' "
                    "because the repository at '${_spm_pkg_dir}' is dirty.\n"
                    "Commit/stash your changes or set "
                    "${_spm_pkg_auto_var}=OFF to keep the current state.")
            endif()
        endif()

        # For WORKTREE/VENDORED we just blow away the directory and recreate.
        # For FULL we prefer in-place update if the dir exists, otherwise clone.
        # TODO:
        #   system for externally cached git repos
        #   a global system cache with entries per repo
        #   does shallow fetches + filtered fetched for ancestry
        #   then copies over worktrees
        #   "FULL" is then adding that as secondary remote and checkout out from there
        if(_spm_checkout_mode STREQUAL "FULL")
            if(NOT _spm_have_dir)
                file(MAKE_DIRECTORY "${SPM_EXTERN_DIR}")
                execute_process(
                    COMMAND git clone "${SPM_GIT_URL}" "${_spm_pkg_dir}"
                    RESULT_VARIABLE _spm_git_res
                )
                if(NOT _spm_git_res EQUAL 0)
                    message(FATAL_ERROR "SPM: git clone failed for '${SPM_NAME}' from '${SPM_GIT_URL}'")
                endif()
            endif()

            execute_process(
                WORKING_DIRECTORY "${_spm_pkg_dir}"
                COMMAND git fetch --all --tags
                RESULT_VARIABLE _spm_git_res
            )
            if(NOT _spm_git_res EQUAL 0)
                message(FATAL_ERROR "SPM: git fetch failed for '${SPM_NAME}' in '${_spm_pkg_dir}'")
            endif()

            execute_process(
                WORKING_DIRECTORY "${_spm_pkg_dir}"
                COMMAND git checkout "${SPM_COMMIT}"
                RESULT_VARIABLE _spm_git_res
            )
            if(NOT _spm_git_res EQUAL 0)
                message(FATAL_ERROR "SPM: git checkout ${SPM_COMMIT} failed for '${SPM_NAME}'")
            endif()

        else()
            # WORKTREE or VENDORED: fresh snapshot of the tree at COMMIT.
            if(_spm_have_dir)
                file(REMOVE_RECURSE "${_spm_pkg_dir}")
            endif()

            # git init <dir>
            execute_process(
                COMMAND git init "${_spm_pkg_dir}"
                RESULT_VARIABLE _spm_git_res
            )
            if(NOT _spm_git_res EQUAL 0)
                message(FATAL_ERROR "SPM: git init failed for '${SPM_NAME}' in '${_spm_pkg_dir}'")
            endif()

            # git remote add origin <url>
            execute_process(
                WORKING_DIRECTORY "${_spm_pkg_dir}"
                COMMAND git remote add origin "${SPM_GIT_URL}"
                RESULT_VARIABLE _spm_git_res
            )
            if(NOT _spm_git_res EQUAL 0)
                message(FATAL_ERROR "SPM: git remote add origin failed for '${SPM_NAME}' from '${SPM_GIT_URL}'")
            endif()

            # git fetch --depth 1 origin <commit>
            execute_process(
                WORKING_DIRECTORY "${_spm_pkg_dir}"
                COMMAND git fetch --depth 1 origin "${SPM_COMMIT}"
                RESULT_VARIABLE _spm_git_res
            )
            if(NOT _spm_git_res EQUAL 0)
                message(FATAL_ERROR "SPM: git fetch --depth 1 origin ${SPM_COMMIT} failed for '${SPM_NAME}'")
            endif()

            # git checkout <commit>
            execute_process(
                WORKING_DIRECTORY "${_spm_pkg_dir}"
                COMMAND git checkout "${SPM_COMMIT}"
                RESULT_VARIABLE _spm_git_res
            )
            if(NOT _spm_git_res EQUAL 0)
                message(FATAL_ERROR "SPM: git checkout ${SPM_COMMIT} failed for '${SPM_NAME}'")
            endif()

            # Drop .git for WORKTREE/VENDORED
            if(EXISTS "${_spm_pkg_dir}/.git")
                file(REMOVE_RECURSE "${_spm_pkg_dir}/.git")
            endif()
        endif()

        # Write meta file for the realized state
        file(WRITE "${_spm_meta}"
            "set(SPM_META_NAME \"${SPM_NAME}\")\n"
            "set(SPM_META_GIT_URL \"${SPM_GIT_URL}\")\n"
            "set(SPM_META_COMMIT \"${SPM_COMMIT}\")\n"
            "set(SPM_META_CHECKOUT \"${_spm_checkout_mode}\")\n"
        )
    endif()

    # Track non-vendored packages for gitignore generation in spm_finalize
    if(NOT _spm_checkout_mode STREQUAL "VENDORED")
        set_property(GLOBAL APPEND PROPERTY SPM_NON_VENDORED_PACKAGES "${SPM_NAME}")
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
