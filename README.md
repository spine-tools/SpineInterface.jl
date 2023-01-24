# SpineInterface.jl

[![Docs](https://img.shields.io/badge/docs-stable-blue.svg)](https://spine-tools.github.io/SpineInterface.jl/latest/index.html)
[![Build Status](https://travis-ci.com/Spine-project/SpineInterface.jl.svg?branch=master)](https://travis-ci.com/Spine-project/SpineInterface.jl)
[![codecov](https://codecov.io/gh/Spine-project/SpineInterface.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/Spine-project/SpineInterface.jl)

A package to interact with Spine databases from a Julia session.
See [Spine](http://www.spine-model.org/) for more information.

### :exclamation: :exclamation:  **GitHub organisation has been renamed!** 

New name [spine-tools](https://github.com/spine-tools), used to be spine-project (19.1.2023). Update your weblinks and git origin to all repositories (in each repository folder `git remote set-url origin https://github.com/spine-tools/repository-name`): Spine Toolbox, SpineOpt.jl, SpineInterface.jl, Spine-Database-API, spine-engine, spine-items.

## Compatibility

This package requires Julia 1.2 or later.

## Installation

```julia
using Pkg
pkg"registry add https://github.com/Spine-project/SpineJuliaRegistry"
pkg"add SpineInterface"
```

## Upgrading
SpineInterface may be updated from time to time. To get the most recent version, just:

1. Start the Julia REPL (can be done also in the Julia console of Spine Toolbox).

2. Copy/paste the following text into the julia prompt:

	```julia
	using Pkg
	Pkg.update("SpineInterface")
	```
	
NOTE. It seems that Pkg.update does not always guarantee the latest version. `Pkg.rm("SpineInterface")` followed by `Pkg.add("SpineInterface")` may help.

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
<img src=docs/src/figs/eu-emblem-low-res.jpg alt="EU emblem" width=100%></td>
<td valign="middle">This work has been partially supported by EU project Mopo (2023-2026), which has received funding from European Climate, Infrastructure and Environment Executive Agency under the European Union’s HORIZON Research and Innovation Actions under grant agreement N°101095998.</td>
<tr>
<td valign="middle" width=100px>
<img src=docs/src/figs/eu-emblem-low-res.jpg alt="EU emblem" width=100%></td>
<td valign="middle">This work has been partially supported by EU project Spine (2017-2021), which has received funding from the European Union’s Horizon 2020 research and innovation programme under grant agreement No 774629.</td>
</table>
</center>
