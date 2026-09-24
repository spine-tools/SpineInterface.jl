# SpineInterface.jl

This package provides access to the contenst of a Spine database
and the ability to create, modify and manage Spine datasets.
The programming interface can be used in 'modern' and 'classic' styles.
The modern style interface is perhaps a more traditional interface
with emphasis on performance rather than convenience.
It is the recommended style for new projects and scripts.
The classic style is a backward-compatibility layer
that uses the modern style behind the scenes.
It allows the continued usage of `using_spinedb` and the convenience functions
in projects and scripts that already use those.

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

Essentially, SpineInterface works just like any Julia module.
The main entry points are

- `empty_entity_class_graph` which creates an empty dataset
- `export_data` which loads data from Spine database
  and `build_entity_class_graph` which converts the loaded data into a dataset
- `data_to_import` which converts an existing dataset into importable data
  and `import_data` which stores the data into Spine database

```julia
using SpineInterface

data = empty_entity_class_graph()
add_entity_class!(data, :colors)
for color in (:red, :blue)
    add_entity!(data, :colors, color)
end
add_entity_class!(data, :shapes)
for shape in (:square, :circle)
    add_entity!(data, :shapes, shape)
end

for color in entities(data, :colors)
    println(color)
end

blob = data_to_import(data)
url = "sqlite:///quick_start.sqlite"
commit_message = "initial commit"
import_data(url, blob, commit_message)
```

## Tutorials

To get started with SpineInterface you can take a look at the tutorials:
+ 'SpineInterface basics' shows basic functionality of SpineInterface in modern style
+ 'Classic interface basics' shows basic functionality with the classic interface
+ 'Classic interface with SpineOpt database' shows the more specific functionality for [SpineOpt](https://github.com/spine-tools/SpineOpt.jl) databases with the classic interface

The files corresponding to these tutorials can be found in the examples folder of the github repository [SpineInterface](https://github.com/spine-tools/SpineInterface.jl).


## Library outline

```@contents
Pages = ["library.md"]
Depth = 3
```
