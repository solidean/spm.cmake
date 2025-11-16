# Shaped Package Manager - spm.cmake

## Quickstart

1. Copy `spm.cmake` into your repo (can be empty)
2. Run `cmake -P spm.cmake -- init-app my-app ma`
   `my-app` is the slug, which is project name, binary name, and include prefix for the files of that project
   `ma` is the default namespace for the project, should be 2-4 chars long
   the uppercased default namespace becomes the prefix for its cmake options


TODO: specify name, specify template

## Commands

* `init` (`init-<templatename>`) - sets up the spm code and applies some template
* `update <lib> <branch-or-commit>` - changes the commit of a package (if branch, resolves it, then changes to that commit)
  * `<lib>` can be "*" to affect all
  * `<branch-or-commit>` can be ":min" to solve for dependency min commits
  * `update * :min` is a useful command to fix stuff
* `vendor <lib>` - copies a package into the repo, removes the gitignore-all, adds VENDORED flag
* `status` - check which packages are dirty
* `fetch <lib>` - updates the library (* allowed) to the given commit

## Rationale

* libraries cannot really be built standalone
  * their dependencies have dependencies
  * and there is no global pinning to use
  * so the workaround is simply "spm init-app" and then


## TODO

continue:
* spm_finalize (for constraint checking)
  * move name normalization into helper (and allow ".")
  * without git repo cache, we can only check for FULL
* make checkout type cache var & overrideable
* git repo cache

* specify multiple templates (layer semantics)
  * move .clang-format into separate layer
  * CMakePresets.json / launch.json / settings.json are _similar_
    but might diverge for app vs lib
* provide templates for app and lib (maybe init-app and init-lib shortcuts?)
* command for showing which files differ from template
* "git merge-base --is-ancestor A B" for min commit
* marking deps as PREBUILD (so they are not part of the main cmake)
* rethink the name and the stylization as "spm.cmake"


## Future

* customization point for non-git min versions
