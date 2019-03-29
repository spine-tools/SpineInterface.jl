module SpineInterface

using PyCall
using JSON
using Dates
using Suppressor

include("checkout_spinedb.jl")
include("write_results.jl")
include("helpers.jl")

export checkout_spinedb
export write_results
export create_results_db

const db_api = PyNULL()
const required_spinedb_api_version = "0.0.22"

function __init__()
    copy!(db_api, pyimport("spinedb_api"))
    current_version = db_api.__version__
    current_version_split = parse.(Int, split(current_version, "."))
    required_version_split = parse.(Int, split(required_spinedb_api_version, "."))
    any(current_version_split .< required_version_split) && error(
"""
SpineInterface couldn't find the required version of `spinedb_api` and needs to be rebuilt:
- Run `import Pkg; Pkg.build("SpineInterface")` to rebuild SpineInterface.
"""
    )
end

end # module
