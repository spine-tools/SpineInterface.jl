module SpineInterface

using DataStructures
using Dates
using JSON
using PyCall
using Sockets
using Statistics
using URIs

include("types.jl")
include("util.jl")
include("base.jl")
include("constructors.jl")
include("using_spinedb.jl")
include("api.jl")

export Anything
export Object
export ObjectLike
export RelationshipLike
export ObjectClass
export RelationshipClass
export Parameter
export AbstractParameterValue
export TimeSlice
export TimeSeries
export Call
export using_spinedb
export anything
export indices
export write_parameters
export members
export groups
export blocks
export duration
export start
export startref
export end_
export roll!
export before
export iscontained
export contains
export overlaps
export overlap_duration
export t_lowest_resolution!
export t_lowest_resolution
export t_highest_resolution!
export t_highest_resolution
export parameter_value
export realize
export is_varying
export object_class
export relationship_class
export parameter
export db_api
export add_objects!
export add_object!
export add_relationships!
export maximum_parameter_value


const db_api = PyNULL()
const required_spinedb_api_version = v"0.10.8"

_spinedb_api_not_found_msg = """
The required Python package `spinedb_api` could not be found in the current Python environment
    $(PyCall.pyprogramname)

You can fix this in two different ways:

    A. Install `spinedb_api` in the current Python environment; open a terminal (command prompt on Windows) and run

        $(PyCall.pyprogramname) -m pip install --user 'git+https://github.com/Spine-project/Spine-Database-API'

    B. Switch to another Python environment that has `spinedb_api` installed; from Julia, run

        ENV["PYTHON"] = "... path of the python executable ..."
        Pkg.build("PyCall")

    And restart Julia.
"""

_spinedb_api_outdated_msg = """
The required version $required_spinedb_api_version of `spinedb_api` could not be found in the current Python environment

    $(PyCall.pyprogramname)

You can fix this in two different ways:

    A. Upgrade `spinedb_api` to its latest version in the current Python environment; open a terminal (command prompt on Windows) and run

        $(PyCall.pyprogramname) -m pip upgrade --user 'git+https://github.com/Spine-project/Spine-Database-API'

    B. Switch to another Python environment that has `spinedb_api` version $required_spinedb_api_version installed; from Julia, run

        ENV["PYTHON"] = "... path of the python executable ..."
        Pkg.build("PyCall")

    And restart Julia.
"""

function _import_spinedb_api()
    if db_api != PyNULL()
        return
    end
    try
        copy!(db_api, pyimport("spinedb_api"))
    catch err
        if err isa PyCall.PyError
            error(_err_msg)
        else
            rethrow()
        end
    end
    current_version = VersionNumber(db_api.__version__)
    if current_version < required_spinedb_api_version
        error(_spinedb_api_outdated_msg)
    end
end

end # module
