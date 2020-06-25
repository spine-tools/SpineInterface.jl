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

@testset "using_spinedb" begin
    url = "sqlite:///$(@__DIR__)/test.sqlite"
    @testset "object_class" begin
	    object_classes = ["institution"]
	    institutions = ["vtt", "kth", "kul", "er", "ucd"]
	    objects = [["institution", x] for x in institutions]
    	db_api.create_new_spine_database(url)
        db_api.import_data_to_url(url; object_classes=object_classes, objects=objects)
        using_spinedb(url)
        @test all(x isa Object for x in institution())
        @test [x.name for x in institution()] == Symbol.(institutions)
    end
end