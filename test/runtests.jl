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

using SpineInterface
import SpineInterface.parse_time_period
using Test
using PyCall
using Dates
using JSON

# Original tests used a slightly different syntax for `import_data`, so correct it here for convenience.
SpineInterface.import_data(db_url::String; kwargs...) = SpineInterface.import_data(db_url, Dict(kwargs...), "testing")

# Convenience function for overwriting in-memory Database with test data.
function import_test_data(db_url::String; kwargs...)
    SpineInterface._import_spinedb_api()
    dbh = SpineInterface._create_db_handler(db_url, false)
    dbh.close_connection()
    dbh.open_connection()
    import_data(db_url; kwargs...)
end

@testset begin
    include("using_spinedb.jl")
    include("api.jl")
    include("constructors.jl")
    include("base.jl")
    include("util.jl")
end
