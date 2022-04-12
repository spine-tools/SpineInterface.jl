# SpineInterface.jl

This package provides the ability to access the contents of a Spine database in a way
that's convenient for writing algorithms.
The function `using_spinedb` is the main star of the package:
Given the url of a Spine database,
it creates a series of convenience functions to retrieve the contents of that database 
in the Julia module or session where it's called.
In this way, you can populate a Spine database with that data for a system you want to study,
call `using_spinedb` in your module to generate the convenience functions,
and then use those functions to build, e.g., an optimisation model for that system.
This allows you to develop fully data-driven applications.
One key example is the [`SpineOpt`](https://github.com/Spine-project/SpineOpt.jl) package,
which uses the above technique to generate and run energy system integration models.

## Compatibility

This package requires Julia 1.2 or later.

## Installation

```julia
julia> using Pkg

julia> pkg"registry add https://github.com/Spine-project/SpineJuliaRegistry"

julia> pkg"add SpineInterface"

```

## Quick start guide

Once `SpineInterface` is installed, to use it in your programs you just need to say:

```jldoctest quick_start_guide
julia> using SpineInterface
```

To generate convenience functions for a Spine database, just run:

```julia
julia> using_spinedb("...url of a Spine database...")
```

**The recomended way of creating, populating, and maintaining Spine databases is through 
[Spine Toolbox](https://github.com/Spine-project/Spine-Toolbox).**
However, here we present an alternative method that only requires `SpineInterface`,
just so you get an idea of how `using_spinedb` works.

Create a new Spine database by running:

```jldoctest quick_start_guide
julia> url = "sqlite:///quick_start.db";

julia> db_api.create_new_spine_database(url);

```

The above will create a SQLite file called `quick_start.db` in the present working directory,
with the Spine database schema in it.

The next step is to add some content to the database. Run:

```jldoctest quick_start_guide
julia> db_api.import_data_to_url(url; object_classes=["actor", "film"])

```

The above will add two object classes called `"actor"` and `"film"` to the database,
and commit the changes so they become visible.

At this point, calling `using_spinedb` will already generate a convenience function for each of these object classes.
Run:

```jldoctest quick_start_guide
julia> using_spinedb(url)

julia> actor()
0-element Array{Union{Int64, T} where T<:SpineInterface.AbstractObject,1}

julia> film()
0-element Array{Union{Int64, T} where T<:SpineInterface.AbstractObject,1}

```

As you can see, both `actor()` and `film()` return 0-element `Array`s.
That's because none of these classes has any objects yet.
Let's see what happens if we add some. Run:

```jldoctest quick_start_guide
julia> objects = [
	["actor", "Phoenix"], 
	["actor", "Johansson"], 
	["film", "Her"], 
	["film", "Joker"]
];

julia> db_api.import_data_to_url(url; objects=objects)

julia> using_spinedb(url)

julia> actor()
2-element Array{Union{Int64, T} where T<:SpineInterface.AbstractObject,1}:
 Phoenix
 Johansson

julia> film()
2-element Array{Union{Int64, T} where T<:SpineInterface.AbstractObject,1}:
 Her
 Joker

julia> film(:Her)
Her

julia> typeof(ans)
Object

```
Things got a little bit more interesting.

Now let's see what happens if we add some relationships to the database:

```jldoctest quick_start_guide
julia> relationship_classes = [["actor__film", ["actor", "film"]]];

julia> relationships = [
	["actor__film", ["Phoenix", "Joker"]], 
	["actor__film", ["Phoenix", "Her"]], 
	["actor__film", ["Johansson", "Her"]]
];

julia> db_api.import_data_to_url(
	url; relationship_classes=relationship_classes, relationships=relationships
)

```

The above will add a relationship class called `"actor__film"` 
between the `"actor"` and `"film"` object classes, and a couple of relationships of that class.
Now let's see the effect of calling `using_spinedb`:

```jldoctest quick_start_guide
julia> using_spinedb(url)

julia> actor__film()
3-element Array{NamedTuple{K,V} where V<:Tuple{Vararg{Union{Int64, T} where T<:SpineInterface.AbstractObject,N} where N} where K,1}:
 (actor = Phoenix, film = Her)
 (actor = Johansson, film = Her)
 (actor = Phoenix, film = Joker)

julia> actor__film(actor=actor(:Johansson))
1-element Array{Object,1}:
 Her

julia> actor__film(film=film(:Her))
2-element Array{Object,1}:
 Johansson
 Phoenix

```

Finally, let's add some parameters and some values to the database:

```jldoctest quick_start_guide
julia> object_parameters = [["film", "release_year"]];

julia> relationship_parameters = [["actor__film", "character_name"]];

julia> object_parameter_values = [
	["film", "Joker", "release_year", 2019],
	["film", "Her", "release_year", 2013],
];

julia> relationship_parameter_values = [
	["actor__film", ["Phoenix", "Joker"], "character_name", "Arthur"], 
	["actor__film", ["Phoenix", "Her"], "character_name", "Theodore"], 
	["actor__film", ["Johansson", "Her"], "character_name", "Samantha"]
];

julia> db_api.import_data_to_url(
	url;
	object_parameters=object_parameters, 
	relationship_parameters=relationship_parameters, 
	object_parameter_values=object_parameter_values,
	relationship_parameter_values=relationship_parameter_values
)
```

And after calling `using_spinedb`:
```
julia> using_spinedb(url)

julia> release_year(film=film(:Joker))
2019

julia> release_year(film=film(:Her))
2013

julia> character_name(film=film(:Joker), actor=actor(:Phoenix))
:Arthur

julia> character_name(actor=actor(:Johansson), film=film(:Her))
:Samantha

julia> character_name(actor=actor(:Johansson), film=film(:Joker))
ERROR: parameter character_name is not specified for argument(s) :actor => Johansson:film => Joker
```



## Library outline

```@contents
Pages = ["library.md"]
Depth = 3
```
