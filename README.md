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
using_spinedb("...url of a Spine database...")
```

## Reporting Issues and Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md)

## License

SpineInterface is licensed under GNU Lesser General Public License version 3.0 or later.

### Acknowledgements

<center>
<table width=500px frame="none">
<tr>
<td valign="middle" width=100px>
<img src=https://europa.eu/european-union/sites/europaeu/files/docs/body/flag_yellow_low.jpg alt="EU emblem" width=100%></td>
<td valign="middle">This project has received funding from the European Union’s Horizon 2020 research and innovation programme under grant agreement No 774629.</td>
</table>
</center>
