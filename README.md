# SpineInterface.jl

[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://spine-project.github.io/SpineInterface.jl/latest/index.html)

A package to interact with Spine databases from a Julia session.
See [Spine](http://www.spine-model.org/) for more information.

## Getting started

### Pre-requisites

- [julia 1.0](https://julialang.org/)
- [PyCall](https://github.com/JuliaPy/PyCall.jl)
- [JSON](https://github.com/JuliaIO/JSON.jl)
- [Suppressor](https://github.com/JuliaData/Suppressor.jl)
- [spinedb_api](https://github.com/Spine-project/Spine-Database-API)

### Installation

From the Julia REPL, press the key `]` to enter the Pkg-REPL mode and run

```julia
(v1.0) pkg> add https://github.com/Spine-project/SpineInterface.jl.git
```

To upgrade to the most recent version, enter the Pkg-REPL mode and run

```julia
(v1.0) pkg> up SpineInterface
```


### Usage

In julia, run

```
using SpineInterface
```

## Reporting Issues and Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md)

## License

SpineInterface.jl is licensed under GNU Lesser General Public License version 3.0 or later.
