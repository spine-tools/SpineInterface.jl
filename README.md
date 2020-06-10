# SpineInterface.jl

[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://spine-project.github.io/SpineInterface.jl/latest/index.html)

A package to interact with Spine databases from a Julia session.
See [Spine](http://www.spine-model.org/) for more information.

## Compatibility

This package requires Julia 1.2 or later.

## Installation

```julia
using Pkg
pkg"registry add https://github.com/Spine-project/SpineJuliaRegistry"
pkg"add SpineInterface"
```

## Usage

```julia
using SpineInterface
using_spinedb(<url of your Spine database>)
```

## Reporting Issues and Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md)

## License

SpineInterface is licensed under GNU Lesser General Public License version 3.0 or later.

