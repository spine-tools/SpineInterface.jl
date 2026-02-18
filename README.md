# SpineInterface.jl

[![Docs](https://img.shields.io/badge/docs-stable-blue.svg)](https://spine-tools.github.io/SpineInterface.jl/latest/index.html)
[![codecov](https://codecov.io/gh/Spine-tools/SpineInterface.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/Spine-tools/SpineInterface.jl)

A package to interact with Spine databases from a Julia session.

## Compatibility

This package supports Julia Long-term support (LTS) up to version 1.11.x


## Installation

You can install SpineInterface as follows:

```julia
using Pkg
pkg"add SpineInterface"
```

However, for keeping up with the latest developments, it is highly recommended to install directly from the source.
This can be done by downloading the repository on your computer, and then installing the module locally with

```julia
using Pkg
Pkg.develop("<PATH_TO_SPINEINTERFACE>")
```

where `<PATH_TO_SPINEINTERFACE>` is the path to the root folder of the SpineInterface repository on your computer *(the one containing the `Project.toml` file)*.

SpineInterface has been primarily designed to work through [Spine Toolbox](https://github.com/spine-tools/Spine-Toolbox),
and shouldn't require specific setup when being called from Spine Toolbox workflows.

When running SpineInterface outside Spine Toolbox *(e.g. from a Julia script directly)*, however,
SpineInterface relies on the [Spine Database API](https://github.com/spine-tools/Spine-Database-API)
Python package, which is accessed using the [PyCall.jl](https://github.com/JuliaPy/PyCall.jl) module.
Thus, one needs to configure PyCall.jl to use a Python executable with Spine Database API installed,
which can be done according to the PyCall readme.
If you're using Conda environments for Python, the `.configure_pycall_in_conda.jl` script can be used to
automatically configure PyCall to use the Python executable of that Conda environment.

## Trouble shooting
When the `Julia` runs under an active `Conda` environment, updating the `Julia` environment raises an error. 
Make sure to deactivate the `Conda` environment before updating the `Julia` environment.
The error is subject to be fixed.

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

Essentially, SpineInterface works just like any Julia module

```julia
using SpineInterface

url = "sqlite:///quick_start.sqlite"
commitmessage = "initial commit"

import_data(url,commitmessage;
	object_classes=["colors", "shapes"],
	objects = [
		["colors", "red"], 
		["colors", "blue"], 
		["shapes", "square"], 
		["shapes", "circle"]
	]
)

using_spinedb(url)

colors()#returns all colors
shapes("square")#returns the square
```

with `import_data` and `using_spinedb` being the key functions for interfacing a Spine Datastore.
`import_data` is used to create a new Spine Datastore or write data to an existing Spine Datastore.
`using_spinedb` creates the convenience functions to access the data in the Spine Datastore.

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
