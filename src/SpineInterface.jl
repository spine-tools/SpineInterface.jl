module SpineInterface

using PyCall
using Dates
using Suppressor
using Statistics
using DataStructures

include("types.jl")
include("util.jl")
include("base.jl")
include("constructors.jl")
include("using_spinedb.jl")
include("api.jl")

const db_api = PyNULL()
const required_spinedb_api_version = v"0.9.4"

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
    pytype_mapping(db_api."parameter_value"."Duration", Duration)
    pytype_mapping(db_api."parameter_value"."TimePattern", TimePattern)
    pytype_mapping(db_api."parameter_value"."TimeSeriesFixedResolution", TimeSeries)
    pytype_mapping(db_api."parameter_value"."TimeSeriesVariableResolution", TimeSeries)
    pytype_mapping(db_api."parameter_value"."Array", Array_)
    pytype_mapping(db_api."parameter_value"."Map", Map)
end

end # module
