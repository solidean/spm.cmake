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
