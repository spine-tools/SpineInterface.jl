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
include("api/db.jl")
include("api/core.jl")
include("api/parameter_value.jl")
include("api/time_slice.jl")
include("api/tests.jl")

export add_dimension!
export add_object_parameter_values!
export add_object_parameter_defaults!
export add_object!
export add_objects!
export add_relationship_parameter_values!
export add_relationship_parameter_defaults!
export add_relationship!
export add_relationships!
export Anything
export anything
export before
export blocks
export Call
export contains
export db_api
export db_value
export difference
export duration
export end_
export export_data
export groups
export import_data
export indexed_values
export collect_indexed_values
export indices
export indices_as_tuples
export iscontained
export Map
export map_to_time_series
export maximum_parameter_value
export members
export Object
export object_class
export object_classes
export ObjectClass
export ObjectLike
export overlap_duration
export overlaps
export Parameter
export parameter
export parameter_value
export parameters
export parse_db_value
export realize
export refresh!
export relationship_class
export relationship_classes
export RelationshipClass
export RelationshipLike
export roll!
export run_request
export start
export startref
export t_highest_resolution
export t_highest_resolution!
export t_highest_resolution_sets!
export t_lowest_resolution
export t_lowest_resolution!
export t_lowest_resolution_sets!
export test_object_class
export test_parameter
export test_relationship_class
export timedata_operation
export TimePattern
export TimeSeries
export TimeSlice
export unparse_db_value
export using_spinedb
export without_filters
export write_parameters

function __init__()
	@require JuMP="4076af6c-e467-56ae-b986-b466b2749572" begin
		include("update_model.jl")
	end
end

end # module
