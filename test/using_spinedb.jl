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
	    institutions = ["VTT", "KTH", "KUL", "ER", "UCD"]
	    objects = [["institution", x] for x in institutions]
    	db_api.create_new_spine_database(url)
        db_api.import_data_to_url(url; object_classes=object_classes, objects=objects)
        using_spinedb(url)
        @test all(x isa Object for x in institution())
        @test [x.name for x in institution()] == Symbol.(institutions)
    end
    @testset "relationship_class" begin
	    object_classes = ["institution", "country"]
	    relationship_classes = [["institution__country", ["institution", "country"]]]
	    institutions = ["VTT", "KTH", "KUL", "ER", "UCD"]
	    countries = ["Sweden", "France", "Finland", "Ireland", "Belgium"]
	    objects = vcat([["institution", x] for x in institutions], [["country", x] for x in countries])
	    relationships = [
	    	["institution__country", ["VTT", "Finland"]],
	    	["institution__country", ["KTH", "Sweden"]],
	    	["institution__country", ["KTH", "France"]],
	    	["institution__country", ["KUL", "Belgium"]],
	    	["institution__country", ["UCD", "Ireland"]],
	    	["institution__country", ["ER", "Ireland"]],
	    	["institution__country", ["ER", "France"]],
	    ]
    	db_api.create_new_spine_database(url)
        db_api.import_data_to_url(
        	url; 
        	object_classes=object_classes, 
        	relationship_classes=relationship_classes, 
        	objects=objects, 
        	relationships=relationships
       	)
        using_spinedb(url)
        @test all(x isa RelationshipLike for x in institution__country())
        @test [x.name for x in institution__country(country=country(:France))] == [:KTH, :ER]
        @test [x.name for x in institution__country(institution=institution(:KTH))] == [:Sweden, :France]
    end
    @testset "parameters" begin
	    object_classes = ["institution", "country"]
	    relationship_classes = [["institution__country", ["institution", "country"]]]
	    object_parameters = [["institution", "since_year"]]
	    relationship_parameters = [["institution__country", "people_count"]]
	    institutions = ["KTH"]
	    countries = ["Sweden", "France"]
	    objects = vcat([["institution", x] for x in institutions], [["country", x] for x in countries])
	    relationships = [
	    	["institution__country", ["KTH", "Sweden"]],
	    	["institution__country", ["KTH", "France"]],
	    ]
	    object_parameter_values = [["institution", "KTH", "since_year", 1827]]
	    relationship_parameter_values = [
	    	["institution__country", ["KTH", "Sweden"], "people_count", 3],
	    	["institution__country", ["KTH", "France"], "people_count", 1],
	    ]
    	db_api.create_new_spine_database(url)
        db_api.import_data_to_url(
        	url; 
        	object_classes=object_classes, 
        	relationship_classes=relationship_classes, 
        	objects=objects, 
        	relationships=relationships,
        	object_parameters=object_parameters,
        	relationship_parameters=relationship_parameters,
        	object_parameter_values=object_parameter_values,
        	relationship_parameter_values=relationship_parameter_values,
       	)
        using_spinedb(url)
        @test all(x isa RelationshipLike for x in institution__country())
        @test people_count(institution=institution(:KTH), country=country(:France)) == 1
        @test people_count(institution=institution(:KTH), country=country(:Sweden)) == 3
        @test since_year(institution=institution(:KTH)) == 1827
    end
end