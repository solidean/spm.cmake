# SPM Template System
#
# This file implements the template mechanism for initializing SPM projects.
# Templates are located in extern/spm.cmake/templates/ and contain project scaffolding.
#
# Templates support variable substitution:
#   @PROJECT_SLUG@ - Replaced with the project slug (e.g., "clean-core")
#   @PROJECT_NAMESPACE@ - Replaced with the project namespace (e.g., "cc")
#   PROJECT_SLUG in paths - Replaced in directory/file names
#
# Example: templates/app/src/PROJECT_SLUG/main.cc
#       -> myproj/src/clean-core/main.cc (with variable substitution in content)

function(spm_apply_template spm_template spm_project_slug spm_project_namespace)
    # Determine template directory
    set(template_dir "${CMAKE_CURRENT_LIST_DIR}/../templates/${spm_template}")

    # Validate that the template exists
    if(NOT EXISTS "${template_dir}" OR NOT IS_DIRECTORY "${template_dir}")
        # Gather available templates for error message
        file(GLOB available_templates LIST_DIRECTORIES true "${CMAKE_CURRENT_LIST_DIR}/../templates/*")
        set(template_list "")
        foreach(tmpl ${available_templates})
            if(IS_DIRECTORY "${tmpl}")
                get_filename_component(tmpl_name "${tmpl}" NAME)
                list(APPEND template_list "${tmpl_name}")
            endif()
        endforeach()

        if(template_list)
            string(REPLACE ";" ", " template_list_str "${template_list}")
            message(FATAL_ERROR "Template '${spm_template}' does not exist.\n"
                "Available templates: ${template_list_str}")
        else()
            message(FATAL_ERROR "Template '${spm_template}' does not exist.\n"
                "No templates found in templates/ directory.")
        endif()
    endif()

    # Set variables for configure_file substitution
    set(PROJECT_SLUG "${spm_project_slug}")
    set(PROJECT_NAMESPACE "${spm_project_namespace}")

    # Get project root (parent of extern directory)
    get_filename_component(project_root "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)

    message(STATUS "Applying template '${spm_template}' to project...")

    # Recursively process all files in the template directory
    file(GLOB_RECURSE template_files RELATIVE "${template_dir}" "${template_dir}/*")

    foreach(template_file ${template_files})
        # Skip directories (GLOB_RECURSE includes them on some platforms)
        if(IS_DIRECTORY "${template_dir}/${template_file}")
            continue()
        endif()

        # Replace PROJECT_SLUG in the path
        string(REPLACE "PROJECT_SLUG" "${spm_project_slug}" target_file "${template_file}")

        # Determine target path
        set(target_path "${project_root}/${target_file}")

        # Only copy if the target file doesn't exist yet
        if(NOT EXISTS "${target_path}")
            # Create parent directory if needed
            get_filename_component(target_dir "${target_path}" DIRECTORY)
            file(MAKE_DIRECTORY "${target_dir}")

            # Copy file with variable substitution using configure_file
            configure_file("${template_dir}/${template_file}" "${target_path}" @ONLY)

            message(STATUS "  Created: ${target_file}")
        else()
            message(STATUS "  Skipped: ${target_file} (already exists)")
        endif()
    endforeach()

    message(STATUS "Template applied successfully.")
endfunction()
