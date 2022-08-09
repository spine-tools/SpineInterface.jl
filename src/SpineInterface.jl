#############################################################################
# Copyright (C) 2017 - 2018  Spine Project
#
# This file is part of SpineInterface.
#
# SpineInterface is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# SpineInterface is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#############################################################################

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
export indices_as_tuples
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
export object_classes
export relationship_class
export relationship_classes
export parameter
export parameters
export db_api
export add_objects!
export add_object_parameter_values!
export add_object!
export add_relationships!
export add_relationship_parameter_values!
export maximum_parameter_value
export parse_db_value
export unparse_db_value
export import_data
export test_object_class
export test_relationship_class
export test_parameter
export timedata_operation
export run_request
export difference
export db_value
export map_to_time_series

function __init__()
	@require JuMP="4076af6c-e467-56ae-b986-b466b2749572" begin
		include("update_model.jl")
		export update_varying_objective!
		export update_varying_constraints!
		export update_model!
	end
end

end # module
