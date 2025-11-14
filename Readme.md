# Shaped Package Manager - spm.cmake

## Quickstart

1. Copy `spm.cmake` into your repo (can be empty)
2. Run `cmake -P spm.cmake -- init-app my-app ma`
   `my-app` is the slug, which is project name, binary name, and include prefix for the files of that project
   `ma` is the default namespace for the project, should be 2-4 chars long


TODO: specify name, specify template


## TODO

* specify multiple templates (layer semantics)
* provide templates for app and lib (maybe init-app and init-lib shortcuts?)
