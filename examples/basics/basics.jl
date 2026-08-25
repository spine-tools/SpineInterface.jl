using SpineInterface
data = empty_entity_class_graph();

add_object_class!(data, :actor);
add_object_class!(data, :film);

add_entity!(data, :actor, :Phoenix);
add_entity!(data, :actor, :Johansson);
add_entity!(data, :film, :Her);
add_entity!(data, :film, :Joker);

collect(entities(data, :actor))
collect(entities(data, :film))

add_relationship_class!(data, :actor__film, :actor, :film);
add_entity!(data, :actor__film, :actor => :Phoenix, :film => :Joker);
add_entity!(data, :actor__film, :actor => :Phoenix, :film => :Her);
add_entity!(data, :actor__film, :actor => :Johansson, :film => :Her);

collect(entities(data, :actor__film))

collect(collect(atoms) for atoms in find_relationships(data, :actor__film))
collect(collect(atoms) for atoms in find_relationships(data, :actor__film, :actor => :Phoenix, anything))
collect(collect(atoms) for atoms in find_relationships(data, :actor__film, anything, :film => :Her))
collect(collect(atoms) for atoms in find_relationships(data, :actor__film, :actor => anything, :film => :Her))
collect(collect(atoms) for atoms in find_relationships(data, :actor__film, (:actor => :Phoenix, :actor => :Johansson), :film => :Her))

collect(Tuple.(find_relationships_compact(data, :actor__film)))
collect(Tuple.(find_relationships_compact(data, :actor__film, :actor => :Phoenix, anything)))
collect(Tuple.(find_relationships_compact(data, :actor__film, anything, :film => :Her)))
collect(collect(atoms) for atoms in find_relationships_compact(data, :actor__film, :actor => anything, :film => :Her))
collect(Tuple.(find_relationships_compact(data, :actor__film, :actor => anything, :film => :Her)))
collect(Tuple.(find_relationships_compact(data, :actor__film, (:actor => :Phoenix, :actor => :Johansson), :film => :Her)))

add_parameter_definition!(data, :film, :release_year, "not given");
set_parameter_value!(data, :film, :release_year, 2019, :Joker);
add_parameter_definition!(data, :actor__film, :character_name);
set_parameter_value!(data, :actor__film, :character_name, "Arthur", :actor => :Phoenix, :film => :Joker);
set_parameter_value!(data, :actor__film, :character_name, "Theodore", :actor => :Phoenix, :film => :Her);
set_parameter_value!(data, :actor__film, :character_name, "Samantha", :actor => :Johansson, :film => :Her);

find_value(data, :film, :release_year, :Joker)
isnothing(find_value(data, :film, :release_year, :Her))
value_or_default(data, :film, :release_year, :Her)
find_value(data, :actor__film, :character_name, :actor => :Phoenix, :film => :Joker)

url = "sqlite:///$(@__DIR__)/example.sqlite";
commit_message = "Initial commit of films and actors.";
import_data(url, data_to_import(data), commit_message);
