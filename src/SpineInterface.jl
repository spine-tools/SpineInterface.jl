#############################################################################
# Copyright (C) 2017 - 2021 Spine project consortium
# Copyright SpineInterface contributors
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
using PrecompileTools

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
export add_parameter_values!
export add_relationship_parameter_values!
export add_relationship_parameter_defaults!
export add_relationship!
export add_relationships!
export Anything
export anything
export before
export blocks
export Call
export collect_updates
export contains
export db_api
export db_value
export db_value_and_type
export difference
export dimensions
export duration
export end_
export export_data
export fixer
export groups
export import_data
export indexed_values
export classes
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
export ParameterValue
export parameter_value
export parameters
export parse_db_value
export parse_time_period
export push_class!
export realize
export relationship_class
export relationship_classes
export RelationshipClass
export RelationshipLike
export roll!
export run_request
export set_value_translator
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
export translate_map_pv_arg!
export unparse_db_value
export using_spinedb
export with_env
export without_filters
export write_parameters
export add_roll_hook!

function __init__()
	@require JuMP="4076af6c-e467-56ae-b986-b466b2749572" begin
		include("update_model.jl")
		export set_expr_bound
	end
end

@setup_workload begin
	using PyCall

	import_data(db_url::String; kwargs...) = import_data(db_url, Dict(kwargs...), "testing")

	function import_test_data(db_url::String; kwargs...)
		SpineInterface.close_connection(db_url)
		SpineInterface.open_connection(db_url)
		import_data(db_url; kwargs...)
	end

    @compile_workload begin
        @testset begin
			#include("../test/using_spinedb.jl")
			#include("../test/api.jl")
			include("../test/constructors.jl")
			include("../test/base.jl")
			include("../test/util.jl")
		end
    end
end

end # module
