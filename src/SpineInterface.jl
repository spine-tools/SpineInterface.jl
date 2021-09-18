module SpineInterface

using DataStructures
using Dates
using JSON
using Sockets
using Statistics
using URIs
using Requires
using Test

include("types.jl")
include("util.jl")
include("base.jl")
include("constructors.jl")
include("using_spinedb.jl")
include("api.jl")
include("tests.jl")

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
export TimePattern
export Map
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
export parse_db_value
export import_data
export test_object_class
export test_relationship_class
export test_parameter
export timedata_operation
export run_request

function __init__()
	@require JuMP="4076af6c-e467-56ae-b986-b466b2749572" begin
		include("update_model.jl")
		export update_varying_objective!
		export update_varying_constraints!
		export update_model!
	end
end

end # module
