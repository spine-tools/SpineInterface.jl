module SpineInterface

using PyCall
using Dates
using Suppressor
using Statistics

include("types.jl")
include("time_slice.jl")
include("period_collection.jl")
include("parameter_value_types.jl")
include("using_spinedb.jl")
include("write_parameters.jl")
include("util.jl")

const db_api = PyNULL()
const required_spinedb_api_version = v"0.0.22"

export Anything
export ObjectClass
export RelationshipClass
export Parameter
export ObjectLike
export Object
export Relationship
export TimeSlice
export using_spinedb
export notusing_spinedb
export write_parameters
export blocks
export duration
export start
export end_
export roll!
export before
export iscontained
export overlaps
export overlap_duration
export t_lowest_resolution
export t_highest_resolution
export TimeSliceMap
export TimeSeries
export indices
export anything


function __init__()
    try
        copy!(db_api, pyimport("spinedb_api"))
    catch err
        if err isa PyCall.PyError
            error(
                """
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
            )
        else
            rethrow()
        end
    end
    current_version = VersionNumber(db_api.__version__)
    current_version >= required_spinedb_api_version || error(
        """
        The required version of `spinedb_api` could not be found in the current Python environment

            $(PyCall.pyprogramname)
            
        You can fix this in two different ways:

        A. Upgrade `spinedb_api` to its latest version in the current Python environment; open a terminal (command prompt on Windows) and run

            $(PyCall.pyprogramname) -m pip upgrade --user 'git+https://github.com/Spine-project/Spine-Database-API'

        B. Switch to another Python environment that has the latest version of `spinedb_api` installed; from Julia, run 

            ENV["PYTHON"] = "... path of the python executable ..."
            Pkg.build("PyCall")

        And restart Julia.
        """
    )
    py"""
    from datetime import datetime
    """
    pytype_mapping(db_api."parameter_value"."DateTime", DateTime_)
    pytype_mapping(db_api."parameter_value"."Duration", DurationLike)
    pytype_mapping(db_api."parameter_value"."TimePattern", TimePattern)
    pytype_mapping(db_api."parameter_value"."TimeSeriesFixedResolution", TimeSeries)
    pytype_mapping(db_api."parameter_value"."TimeSeriesVariableResolution", TimeSeries)
end

end # module
