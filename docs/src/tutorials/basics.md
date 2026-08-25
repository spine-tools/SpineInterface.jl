# SpineInterface basics

This tutorial introduces some basic concepts of SpineInterface.
We will use the modern graph-based interface here.
For the classic interface (`using_spinedb` + convenience functions),
see the classic tutorials.

Once you have installed SpineInterface, and activated and instatiated the Julia environment,
we can start by creating an empty dataset:

```julia
julia> using SpineInterface
[...]
julia> data = empty_entity_class_graph();
```

Now, `data` holds an empty entity class graph, more precisely, an instance of MetaGraph.
It holds all necessary information to start modelling:
entity classes, entities, parameter definitions and parameter values.

Generally, it is not necessary know the details of the graph or even that `data` is a graph at all.
SpineInterface offers high-level functions to work with the graph without this knowledge.
However, if you want to dive into the details, you can use the low-level functions
from the [MetaGraphsNext](https://juliagraphs.org/MetaGraphsNext.jl/stable/) library.

Let's add some data to our dataset:

```julia
julia> add_object_class!(data, :actor);

julia> add_object_class!(data, :film);
```

The above will add two object classes called "actor" and "film" to out dataset.
Note, how we use symbols for names in SpineInterface.
Next, let's add some concrete actors and films:

```julia
julia> add_entity!(data, :actor, :Phoenix);

julia> add_entity!(data, :actor, :Johansson);

julia> add_entity!(data, :film, :Her);

julia> add_entity!(data, :film, :Joker);
```

We can use the `entities` iterator to check the contents of the newly created classes:

```julia
julia> collect(entities(data, :actor))
2-element Vector{Symbol}:
 :Johansson
 :Phoenix

julia> collect(entities(data, :film))
2-element Vector{Symbol}:
 :Her
 :Joker
```

To make things more interesting, let's add relationships that record which actor has acted in which film:

```julia
julia> add_relationship_class!(data, :actor__film, :actor, :film);

julia> add_entity!(data, :actor__film, :actor => :Phoenix, :film => :Joker);

julia> add_entity!(data, :actor__film, :actor => :Phoenix, :film => :Her);

julia> add_entity!(data, :actor__film, :actor => :Johansson, :film => :Her);
```

Notice, how we specify the relationship using pairs:
the first element in the pair is the object class, the second is the object.
These pairs are called atoms of the relationship.

We can use the `entities` iterator above to get all the atoms we just added:

```julia
julia> collect(entities(data, :actor__film))
3-element Vector{Tuple{Pair{Symbol, Symbol}, Pair{Symbol, Symbol}}}:
 (:actor => :Phoenix, :film => :Joker)
 (:actor => :Phoenix, :film => :Her)
 (:actor => :Johansson, :film => :Her)
```

Note, that the order in which `entities` returns its results is not specified.
The latest relationship that was added is not necessarily the last on the list.

SpineInterface offers some powerful methods to find specific relationships in a class.
Let's first have a look at how `find_relationships` works:

```julia
julia> collect(collect(atoms) for atoms in find_relationships(data, :actor__film))
3-element Vector{Vector{Pair{Symbol, Symbol}}}:
 [:actor => :Phoenix, :film => :Joker]
 [:actor => :Phoenix, :film => :Her]
 [:actor => :Johansson, :film => :Her]

julia> collect(collect(atoms) for atoms in find_relationships(data, :actor__film, :actor => :Phoenix, anything))
2-element Vector{Vector{Pair{Symbol, Symbol}}}:
 [:actor => :Phoenix, :film => :Joker]
 [:actor => :Phoenix, :film => :Her]

julia> collect(collect(atoms) for atoms in find_relationships(data, :actor__film, anything, :film => :Her))
2-element Vector{Vector{Pair{Symbol, Symbol}}}:
 [:actor => :Phoenix, :film => :Her]
 [:actor => :Johansson, :film => :Her]

julia> collect(collect(atoms) for atoms in find_relationships(data, :actor__film, :actor => anything, :film => :Her))
2-element Vector{Vector{Pair{Symbol, Symbol}}}:
 [:actor => :Phoenix, :film => :Her]
 [:actor => :Johansson, :film => :Her]
```

The first thing to note in the code above is that `find_relationships` returns iterators.
This is to avoid memory allocations if you just want to loop over the relationships and their atoms.
Otherwise, we are responsible for allocating the required data structures e.g. by calling `collect` like we did above.

Secondly, we can use the `anything` singleton as a "wild card".
The `<class> => anything` form that we used in the last example above is useful in the case
where any of the dimensions of the relationship class are superclasses.
This form forces `find_relationships` to find relationships with the specific class,
and not consider other subclasses.

There is an alternative to `find_relationships` that only returns dimensions that are set to `anything` in the call.
It is called `find_relationships_compact`:

```julia
julia> collect(Tuple.(find_relationships_compact(data, :actor__film)))
3-element Vector{Tuple{Pair{Symbol, Symbol}, Pair{Symbol, Symbol}}}:
 (:actor => :Phoenix, :film => :Joker)
 (:actor => :Phoenix, :film => :Her)
 (:actor => :Johansson, :film => :Her)

julia> collect(Tuple.(find_relationships_compact(data, :actor__film, :actor => :Phoenix, anything)))
2-element Vector{Tuple{Pair{Symbol, Symbol}}}:
 (:film => :Joker,)
 (:film => :Her,)

julia> collect(Tuple.(find_relationships_compact(data, :actor__film, anything, :film => :Her)))
2-element Vector{Tuple{Pair{Symbol, Symbol}}}:
 (:actor => :Phoenix,)
 (:actor => :Johansson,)

julia> collect(collect(atoms) for atoms in find_relationships_compact(data, :actor__film, :actor => anything, :film => :Her))
2-element Vector{Vector{Pair{Symbol, Symbol}}}:
 [:actor => :Phoenix]
 [:actor => :Johansson]

julia> collect(Tuple.(find_relationships_compact(data, :actor__film, :actor => anything, :film => :Her)))
2-element Vector{Tuple{Pair{Symbol, Symbol}}}:
 (:actor => :Phoenix,)
 (:actor => :Johansson,)
```

Let's add some parameters to the dataset:

```julia
julia> add_parameter_definition!(data, :film, :release_year);

julia> set_parameter_value!(data, :film, :release_year, 2019, :Joker);

julia> add_parameter_definition!(data, :actor__film, :character_name);

julia> set_parameter_value!(data, :actor__film, :character_name, "Arthur", :actor => :Phoenix, :film => :Joker);

julia> set_parameter_value!(data, :actor__film, :character_name, "Theodore", :actor => :Phoenix, :film => :Her);

julia> set_parameter_value!(data, :actor__film, :character_name, "Samantha", :actor => :Johansson, :film => :Her);
```

We can use `find_value` and `value_or_default `to access the parameters:

```julia
julia> find_value(data, :film, :release_year, :Joker)
ParameterValue(2019)

julia> isnothing(find_value(data, :film, :release_year, :Her))
true

julia> value_or_default(data, :film, :release_year, :Her)
ParameterValue(not given)

julia> find_value(data, :actor__film, :character_name, :actor => :Phoenix, :film => :Joker)
ParameterValue(Arthur)
```

In the above, `find_value` returns `nothing` for the release year of Her because the value is not set.
`value_or_default`, on the other hand, returns the default value
that is set when the parameter is introduced by `add_parameter_definition!`.

Finally, let's store the dataset to a Spine database, so it can be accessed later for example
in [Spine Toolbox](https://github.com/spine-tools/Spine-Toolbox):

```julia
julia> url = "sqlite:///$(@__DIR__)/example.sqlite";

julia> commit_message = "Initial commit of films and actors.";

julia> import_data(url, data_to_import(data), commit_message);
```
