# SPM Initialization Handler
#
# This file is included by the bootstrap script after cloning the SPM repository.
# It processes init commands and applies the appropriate project template.
#
# Expected variables:
#   spm_command - The command starting with "init" (e.g., "init", "init-app", "init-lib")
#   spm_args    - Additional arguments (must be exactly 2: project-slug and namespace)

# Validate arguments
# Require exactly two arguments: project slug and namespace
list(LENGTH spm_args spm_args_count)
if(NOT spm_args_count EQUAL 2)
    message(FATAL_ERROR "Init command requires exactly 2 arguments: <project-slug> <namespace>\n"
        "Example: cmake -P spm.cmake -- init clean-core cc\n"
        "Got ${spm_args_count} argument(s)")
endif()

# Extract project slug and namespace from arguments
list(GET spm_args 0 spm_project_slug)
list(GET spm_args 1 spm_project_namespace)

# Determine which template to apply
# Default template is "app"
# For commands like "init-xyz", extract "xyz" as the template name
if(spm_command STREQUAL "init")
    set(spm_template "app")
else()
    # Extract template name from "init-<template>"
    string(REGEX REPLACE "^init-(.+)$" "\\1" spm_template "${spm_command}")
endif()

# Apply the selected template
spm_apply_template(${spm_template} ${spm_project_slug} ${spm_project_namespace})
