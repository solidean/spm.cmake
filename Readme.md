# Shaped Package Manager - spm.cmake

## Quickstart

1. Copy `spm.cmake` into your repo (can be empty)
2. Run `cmake -P spm.cmake -- init-app my-app ma`
   `my-app` is the slug, which is project name, binary name, and include prefix for the files of that project
   `ma` is the default namespace for the project, should be 2-4 chars long
   the uppercased default namespace becomes the prefix for its cmake options


TODO: specify name, specify template


## TODO

* specify multiple templates (layer semantics)
  * move .clang-format into separate layer
  * CMakePresets.json / launch.json / settings.json are _similar_
    but might diverge for app vs lib
* provide templates for app and lib (maybe init-app and init-lib shortcuts?)
* command for showing which files differ from template
* "git merge-base --is-ancestor A B" for min commit


## Future

* customization point for non-git min versions
