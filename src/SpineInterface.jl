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
include("helpers.jl")
include("util.jl")

const db_api = PyNULL()
const required_spinedb_api_version = "0.0.22"

export Anything
export ObjectClass
export RelationshipClass
export Parameter
export ObjectLike
export Object
export TimeSlice
export using_spinedb
export notusing_spinedb
export write_parameters
export duration
export start
export end_
export before
export iscontained
export overlaps
export overlap_duration
export t_lowest_resolution
export t_highest_resolution
export TimeSeries
export indices
export anything
export to_database
export update!


function __init__()
    copy!(db_api, pyimport("spinedb_api"))
    current_version = db_api.__version__
    current_version_split = parse.(Int, split(current_version, "."))
    required_version_split = parse.(Int, split(required_spinedb_api_version, "."))
    any(current_version_split .< required_version_split) && error(
        """
        SpineInterface couldn't find the required version of `spinedb_api` and needs to be rebuilt:
        Please run `import Pkg; Pkg.build("SpineInterface")` to rebuild SpineInterface.
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
