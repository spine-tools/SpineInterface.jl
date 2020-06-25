# SpineInterface.jl

[![Docs](https://img.shields.io/badge/docs-stable-blue.svg)](https://spine-project.github.io/SpineInterface.jl/latest/index.html)
[![Build Status](https://travis-ci.com/Spine-project/SpineInterface.jl.svg?branch=master)](https://travis-ci.com/Spine-project/SpineInterface.jl)
[![Coverage Status](https://coveralls.io/repos/github/Spine-project/SpineInterface.jl/badge.svg?branch=master)](https://coveralls.io/github/Spine-project/SpineInterface.jl?branch=master)
[![codecov](https://codecov.io/gh/Spine-project/SpineInterface.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/Spine-project/SpineInterface.jl)

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

