# SPM Design (+ Naming + Bikeshedding)

## Package

In SPM, a **package** is the fundamental unit of management: 
a self-contained external resource that your project depends on. 
A package is usually a git repository, but it can also be a script collection, a tooling repo, or anything you would previously have pulled in via submodules. 
Packages are identified by a stable name, and the root application chooses exactly which commit of each package is used in a build.

A package is deliberately broader than “library.” 
Many real projects need external tools, code generators, test helpers, or workflow scripts. 
Treating all of these as packages keeps the model uniform: 
every external resource is pinned by the app, and every library can declare lightweight constraints on the packages it needs.

The name “package” was chosen after considering several alternatives:

* **library** was too narrow; not all dependencies provide buildable artifacts.
* **module** carries heavy meaning in C++ and other languages and would invite confusion.
* **dependency** describes the *relation*, not the thing being depended on.
* **repo** would hard-wire git into the concept and fail to generalize.

“Package” cleanly captures what SPM manages: 
individual external units of code or assets, each with its own source, version, and constraints. 
It is neutral, precise, and familiar from other ecosystems.


## Extern

`extern/` is the directory where SPM stores all managed packages. 
It is the physical root of SPM’s dependency world: 
every package fetched by SPM ends up as `extern/<package-name>`. 
This location is intentionally flat and predictable so that SPM can reason about package identity, deduplication, ancestry checks, and update operations without special cases.

The term *extern* was chosen because it captures the intent cleanly: 
these items are external to the project’s own source tree but brought inside the repository for reproducible builds or development experience. 
Other common names were considered—`vendor/`, `deps/`, `third_party/`—but they carry narrower connotations. 
`vendor/` implies vendoring; `third_party/` suggests external libraries only; `deps/` sounds build-centric. 
`extern/` stays neutral and general, matching SPM’s goal of managing libraries, tools, scripts, assets, and anything formerly handled via submodules.

At this stage the location is neither configurable nor overrideable. 
A fixed root keeps the system simple: tools don’t need to scan multiple directories, users can reliably grep for `extern/<name>`, and SPM’s internal logic can assume a single layout. 
Global overrides would complicate project portability; per-package overrides would fracture the layout and make tooling brittle.

If a package should be more visible—for example, developer-facing tools or workflow utilities—there are lightweight workarounds that keep SPM’s layout stable while improving ergonomics:

* **Symlinks:** `tools/website-tester -> ../extern/website-tester` for platforms that support them.
* **Wrapper scripts:** `tools/website-tester` containing a simple forwarder into `extern/website-tester`.
* **Alias commands:** small project-local scripts or shell functions that call into a package’s executable.

These approaches give humans a friendlier surface without compromising SPM’s invariant: all managed packages live in one predictable place. 
This simplicity pays off when debugging, scripting, and reasoning about the dependency graph.
