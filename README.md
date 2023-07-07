# SpineInterface.jl

[![Docs](https://img.shields.io/badge/docs-stable-blue.svg)](https://spine-tools.github.io/SpineInterface.jl/latest/index.html)
[![codecov](https://codecov.io/gh/Spine-tools/SpineInterface.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/Spine-tools/SpineInterface.jl)

A package to interact with Spine databases from a Julia session.
See [Spine](http://www.spine-model.org/) for more information.

## Compatibility

This package requires Julia 1.6 or later.


## Installation

You can install SpineInterface from the SpineJuliaRegistry as follows:

```julia
using Pkg
pkg"registry add https://github.com/Spine-tools/SpineJuliaRegistry"
pkg"add SpineInterface"
```

However, for keeping up with the latest developments, it is highly recommended to install directly from the source.
This can be done by downloading the repository on your computer, and then installing the module locally with

```julia
using Pkg
Pkg.develop("<PATH_TO_SPINEINTERFACE>")
```

where `<PATH_TO_SPINEINTERFACE>` is the path to the root folder of the SpineInterface repository on your computer *(the one containing the `Project.toml` file)*. 


## Upgrading

SpineInterface may be updated from time to time. To get the most recent version, just:

1. Start the Julia REPL (can be done also in the Julia console of Spine Toolbox).

2. Copy/paste the following text into the julia prompt:

	```julia
	using Pkg
	Pkg.update("SpineInterface")
	```
	
NOTE. It seems that Pkg.update does not always guarantee the latest version. `Pkg.rm("SpineInterface")` followed by `Pkg.add("SpineInterface")` may help.

If you have installed SpineInterface from source locally on your machine, you can update it simply by pulling the latest `master` from the repository.


## Usage

SpineInterface has been primarily designed to work through [Spine Toolbox](https://github.com/spine-tools/Spine-Toolbox),
and shouldn't require specific setup when being called from Spine Toolbox workflows.
Essentially, SpineInterface works just like any Julia module

```julia
using SpineInterface
using_spinedb("...url of a Spine database...")
```

with `using_spinedb` being the key function that creates the interface for a Spine Datastore.

When running SpineInterface outside Spine Toolbox *(e.g. from a Julia script directly)*, however,
SpineInterface relies on the [Spine Database API](https://github.com/spine-tools/Spine-Database-API)
Python package, which is accessed using the [PyCall.jl](https://github.com/JuliaPy/PyCall.jl) module.
Thus, one needs to configure PyCall.jl to use a Python executable with Spine Database API installed,
which can be done according to the PyCall readme.
If you're using Conda environments for Python, the `.configure_pycall_in_conda.jl` script can be used to
automatically configure PyCall to use the Python executable of that Conda environment.


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
