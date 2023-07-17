# SpineInterface.jl

This package provides the ability to access the contents of a Spine database in a way
that's convenient for writing algorithms.
The functions `import_data` and `using_spinedb` are the main stars of the package:
Given the url of a Spine database, `import_data` can write data to the (new) database
and `using_spinedb` creates a series of convenience functions to retrieve the contents of that database 
in the Julia module or session where it's called.
In this way,
with `import_data` you can populate a Spine database with that data for a system you want to study,
call `using_spinedb` in your module to generate the convenience functions,
and then use those functions to build, e.g., an optimisation model for that system.
This allows you to develop fully data-driven applications.
One key example is the [`SpineOpt`](https://github.com/Spine-project/SpineOpt.jl) package,
which uses the above technique to generate and run energy system integration models.

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

!!! note
	SpineInterface has been primarily designed to work through [Spine Toolbox](https://github.com/spine-tools/Spine-Toolbox),
	and shouldn't require specific setup when being called from Spine Toolbox workflows.

	When running SpineInterface outside Spine Toolbox *(e.g. from a Julia script directly)*, however,
	SpineInterface relies on the [Spine Database API](https://github.com/spine-tools/Spine-Database-API)
	Python package, which is accessed using the [PyCall.jl](https://github.com/JuliaPy/PyCall.jl) module.
	Thus, one needs to configure PyCall.jl to use a Python executable with Spine Database API installed,
	which can be done according to the PyCall readme.
	If you're using Conda environments for Python, the `.configure_pycall_in_conda.jl` script can be used to
	automatically configure PyCall to use the Python executable of that Conda environment.

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


## Tutorials

To get started with SpineInterface you can take a look at the tutorials:
+ 'Tutorial spine database' shows the basic functionality of SpineInterface for general spine databases
+ 'Tutorial SpineOpt database' shows the more specific functionality for [SpineOpt](https://github.com/Spine-tools/SpineOpt.jl) databases

The files corresponding to these tutorials can be found in the examples folder of the github repository [SpineInterface](https://github.com/Spine-tools/SpineInterface.jl).


## Library outline

```@contents
Pages = ["library.md"]
Depth = 3
```