#=
    .configure_pycall_in_conda.jl

A script for automatically configuring SpineInterface PyCall inside a Conda environment.

NOTE! 
1. This script needs to be run from Julia inside an active Conda environment with
`spinedb_api`! (e.g. the one included in a Spine Toolbox installation)
2. SpineInterface.jl needs to be installed with its development dependencies, 
i.e. `Pkg.develop("path/to/SpineInterface.jl")`,
in the environment associated with the directory of this script (@__DIR__).
=#

# Activate the SpineInterface module in this directory.
using Pkg 
Pkg.activate(@__DIR__)

# Set PyCall "PYTHON" based on active Conda "CONDA_PREFIX" environment.
ENV["PYTHON"] = ENV["CONDA_PREFIX"] * "\\python.exe"

# Install SpineInterface dependencies
# Pkg.instantiate()
# Temporarily remove the above line to avoid the error from
# updating the Julia environment under an active Conda environment.

# Re-build PyCall just to be sure
Pkg.build("PyCall")