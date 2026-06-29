#=
    .configure_pycall_in_venv.jl

A script for automatically configuring SpineInterface PyCall inside a Python venv.

NOTE! 
1. This script needs to be run from Julia inside an active Python venv with
`spinedb_api`! (e.g. the one included in a Spine Toolbox installation)
2. SpineInterface.jl needs to be installed with its development dependencies, 
i.e. `Pkg.develop("path/to/SpineInterface.jl")`,
in the environment associated with the directory of this script (@__DIR__).
=#

# Activate the SpineInterface module in this directory.
using Pkg 
Pkg.activate(@__DIR__)

# Set PyCall "PYTHON" based on active venv "VIRTUAL_ENV" environment.
ENV["PYTHON"] = ENV["VIRTUAL_ENV"] * "\\Scripts\\python.exe"

# Install SpineInterface dependencies
Pkg.instantiate()

# Re-build PyCall just to be sure
Pkg.build("PyCall")