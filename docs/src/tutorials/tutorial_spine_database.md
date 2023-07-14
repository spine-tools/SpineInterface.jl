# Tutorial spine database

Once `SpineInterface` is installed, we can start using it in Julia scripts or consoles.

```jldoctest quick_start_guide
julia> using SpineInterface
```

We can immediately start to add objects to a non-existing database
because the database will automatically be created.
That does imply that small writing mistakes result in new databases.
To avoid writing mistakes it is recommended to make a variable that refers to the url.

!!! note
    The recomended way of creating, populating, and maintaining Spine databases is through 
    [Spine Toolbox](https://github.com/spine-tools/Spine-Toolbox).
    As an example, the tutorial folder contains an empty spine database created with Spine Toolbox.
    That database can be used instead of creating a new database.

```jldoctest quick_start_guide
julia> url = "sqlite:///quick_start.sqlite"

julia> commit_message="initial commit message for the new database with the objects actor and film"

julia> import_data(url, commit_message; object_classes=["actor", "film"])
```

The above will create a SQLite file called `quick_start.sqlite` in the present working directory,
with the Spine database schema and commits the specified changes to the database (the process uses a git workflow)
The content consists of two object classes called `"actor"` and `"film"`.

To generate convenience functions for that database, you can call `using_spinedb`.

!!! note
	Note that `using_spinedb` may require the Julia package PyCall to function properly.

```jldoctest quick_start_guide
julia> using_spinedb(url)

julia> actor()
0-element Array{Union{Int64, T} where T<:SpineInterface.AbstractObject,1}

julia> film()
0-element Array{Union{Int64, T} where T<:SpineInterface.AbstractObject,1}

```

As you can see, both `actor()` and `film()` return 0-element `Array`s.
That's because none of these classes has any objects yet.
Let's see what happens if we add some.

```jldoctest quick_start_guide
julia> objects = [
	["actor", "Phoenix"], 
	["actor", "Johansson"], 
	["film", "Her"], 
	["film", "Joker"]
];

julia> import_data(url, "add objects"; objects=objects)

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

julia> import_data(
	url, "add relationships"; relationship_classes=relationship_classes, relationships=relationships
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

julia> import_data(
	url,
    "add parameters";
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

The full script can be found in the tutorials folder.