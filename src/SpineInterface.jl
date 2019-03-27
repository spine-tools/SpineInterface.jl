module SpineInterface

using PyCall
using JSON
using Dates
using Suppressor

include("spine_checkout.jl")
include("write_results.jl")
include("helpers.jl")
include("butcher.jl")

export spine_checkout
export write_results
export @butcher

const db_api = PyNULL()
const required_spinedb_api_version = "0.0.21"

function __init__()
    try
        copy!(db_api, pyimport("spinedb_api"))
    catch e
        if isa(e, PyCall.PyError) && pyisinstance(e.val, py"ModuleNotFoundError")
            try
                copy!(db_api, pyimport("spinedatabase_api"))  # Older name
            catch e
                if isa(e, PyCall.PyError) && pyisinstance(e.val, py"ModuleNotFoundError")
                    error(
"""
SpineInterface couldn't find the required Python module `spinedb_api`.
Please make sure `spinedb_api` is in your Python path, restart your Julia session,
and try using SpineInterface again.

NOTE: if you have already installed Spine Toolbox, then you can use the same `spinedb_api`
provided with it in SpineInterface.
All you need to do is configure PyCall to use the same Python program as Spine Toolbox. Run

    ENV["PYTHON"] = "... path of the Python program you want ..."

followed by

    Pkg.build("PyCall")

If you haven't installed Spine Toolbox or don't want to reconfigure PyCall, then you can do the following:

1. Find out the path of the Python program used by PyCall. Run

    PyCall.pyprogramname

2. Install spinedb_api using that Python. Open a terminal (e.g. command prompt on Windows) and run

    python -m pip install git+https://github.com/Spine-project/Spine-Database-API.git

where 'python' is the path returned by `PyCall.pyprogramname`.
"""
                    )
                else
                    rethrow()
                end
            end
        else
            rethrow()
        end
    end
    current_version = db_api.__version__
    current_version_split = parse.(Int, split(current_version, "."))
    required_version_split = parse.(Int, split(required_spinedb_api_version, "."))
    any(current_version_split .< required_version_split) && error(
"""
SpineInterface couldn't find the required version of `spinedb_api`.
(Required version is $required_spinedb_api_version, whereas current is $current_version)
Please upgrade `spinedb_api` to $required_spinedb_api_version, restart your julia session,
and try using SpineInterface again.

To upgrade `spinedb_api`, open a terminal (e.g. command prompt on Windows) and run

    pip install --upgrade git+https://github.com/Spine-project/Spine-Database-API.git
"""
    )
end

end # module
