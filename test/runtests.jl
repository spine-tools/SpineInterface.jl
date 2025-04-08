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

using SpineInterface
import SpineInterface.parse_time_period
using Test
using PyCall
using Dates
using JSON
using JuMP
using HiGHS

# Handle JuMP and SpineInterface `Parameter` and `parameter_value` conflicts.
import SpineInterface: Parameter, parameter_value

# Original tests used a slightly different syntax for `import_data`, so correct it here for convenience.
SpineInterface.import_data(db_url::String; kwargs...) = SpineInterface.import_data(db_url, Dict(kwargs...), "testing")

# Convenience function for overwriting in-memory Database with test data.
function import_test_data(db_url::String; kwargs...)
    SpineInterface.close_connection(db_url)
    SpineInterface.open_connection(db_url)
    import_data(db_url; kwargs...)
end

@testset begin
    include("using_spinedb.jl")
    include("api.jl")
    include("constructors.jl")
    include("base.jl")
    include("util.jl")
    include("update_model.jl")
    @testset "examples" begin 
        include("../examples/tutorial_spine_database/tutorial_spine_database.jl")
        include("../examples/tutorial_spineopt_database/tutorial_spineopt_database.jl")
    end
end
