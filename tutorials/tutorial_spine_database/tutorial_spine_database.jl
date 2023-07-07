# Tutorial spine database

using SpineInterface

# initialize database
url = "sqlite:///quick_start.sqlite"
commit_message="initial commit message for the new database with the objects actor and film"
import_data(url, commit_message; object_classes=["actor", "film"])

using_spinedb(url)
@show actor()
@show film()

# Add objects
objects = [
	["actor", "Phoenix"], 
	["actor", "Johansson"], 
	["film", "Her"], 
	["film", "Joker"]
]

import_data(url, "add objects"; objects=objects)

using_spinedb(url)

@show actor()
@show film()
@show film(:Her)
@show typeof(film(:Her))

# Add relationships
relationship_classes = [["actor__film", ["actor", "film"]]]

relationships = [
	["actor__film", ["Phoenix", "Joker"]], 
	["actor__film", ["Phoenix", "Her"]], 
	["actor__film", ["Johansson", "Her"]]
]

import_data(
	url, "add relationships"; relationship_classes=relationship_classes, relationships=relationships
)

using_spinedb(url)

@show actor__film()
@show actor__film(actor=actor(:Johansson))
@show actor__film(film=film(:Her))

# Add parameters
object_parameters = [["film", "release_year"]]

relationship_parameters = [["actor__film", "character_name"]]

object_parameter_values = [
	["film", "Joker", "release_year", 2019],
	["film", "Her", "release_year", 2013],
]

relationship_parameter_values = [
	["actor__film", ["Phoenix", "Joker"], "character_name", "Arthur"], 
	["actor__film", ["Phoenix", "Her"], "character_name", "Theodore"], 
	["actor__film", ["Johansson", "Her"], "character_name", "Samantha"]
]

import_data(
	url,
    "add parameters";
	object_parameters=object_parameters, 
	relationship_parameters=relationship_parameters, 
	object_parameter_values=object_parameter_values,
	relationship_parameter_values=relationship_parameter_values
)

using_spinedb(url)

@show release_year(film=film(:Joker))
@show release_year(film=film(:Her))
@show character_name(film=film(:Joker), actor=actor(:Phoenix))
@show character_name(actor=actor(:Johansson), film=film(:Her))
try
    character_name(actor=actor(:Johansson), film=film(:Joker))
catch
    println("This produces an error because Johansson is not in Joker.")
end