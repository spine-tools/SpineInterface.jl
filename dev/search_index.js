var documenterSearchIndex = {"docs":
[{"location":"#SpineInterface.jl-1","page":"Home","title":"SpineInterface.jl","text":"","category":"section"},{"location":"#","page":"Home","title":"Home","text":"This package provides the ability to access the contents of a Spine database in a way that's convenient for writing algorithms. The function using_spinedb is the main star of the package. It receives the url of a Spine database and a Julia module,  and creates a series of convenience functions to retrieve the contents of the database inside that module. In this way, you can populate a Spine database with your data for, e.g., and optimisation model, call using_spinedb to generate convenience functions, and then use those functions in your module to do something specific. This allows you to develop fully data-driven applications. One key example is the SpineOpt package, which uses this technique to generate and run energy system integration models.","category":"page"},{"location":"#Compatibility-1","page":"Home","title":"Compatibility","text":"","category":"section"},{"location":"#","page":"Home","title":"Home","text":"This package requires Julia 1.2 or later.","category":"page"},{"location":"#Installation-1","page":"Home","title":"Installation","text":"","category":"section"},{"location":"#","page":"Home","title":"Home","text":"julia> using Pkg\r\n\r\njulia> pkg\"registry add https://github.com/Spine-project/SpineJuliaRegistry\"\r\n\r\njulia> pkg\"add SpineInterface\"\r\n","category":"page"},{"location":"#Quick-start-guide-1","page":"Home","title":"Quick start guide","text":"","category":"section"},{"location":"#","page":"Home","title":"Home","text":"Once SpineInterface is installed, to use it in your programs you just need to say:","category":"page"},{"location":"#","page":"Home","title":"Home","text":"julia> using SpineInterface","category":"page"},{"location":"#","page":"Home","title":"Home","text":"To generate convenience functions for a Spine database, just run:","category":"page"},{"location":"#","page":"Home","title":"Home","text":"julia> using_spinedb(\"...url of a Spine database...\")","category":"page"},{"location":"#","page":"Home","title":"Home","text":"The recomended way of creating, populating, and maintaining Spine databases is through  Spine Toolbox. However, here we present an alternative method that only requires SpineInterface, just so you get an idea of how using_spinedb works.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"Create a new Spine database and mapping by running:","category":"page"},{"location":"#","page":"Home","title":"Home","text":"julia> url = \"sqlite:///example.db\";\n\njulia> db_map = create_spinedb_map(url);\n","category":"page"},{"location":"#","page":"Home","title":"Home","text":"The above will create a SQLite file called example.db in the present working directory with the Spine database schema, together with a database mapping object, db_map, which is a handle to the database in Julia.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"The next step is to add some content to the database. Run:","category":"page"},{"location":"#","page":"Home","title":"Home","text":"julia> import_and_commit(db_map; object_classes=[\"actor\", \"film\"])\n","category":"page"},{"location":"#","page":"Home","title":"Home","text":"The above will add two object classes called \"actor\" and \"film\" to the database, and commit the changes so they become visible.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"At this point, calling using_spinedb will already generate a convenience function for each of these object classes. Run:","category":"page"},{"location":"#","page":"Home","title":"Home","text":"julia> using_spinedb(url)\n\njulia> actor()\n0-element Array{Union{Int64, T} where T<:SpineInterface.AbstractObject,1}\n\njulia> film()\n0-element Array{Union{Int64, T} where T<:SpineInterface.AbstractObject,1}\n","category":"page"},{"location":"#","page":"Home","title":"Home","text":"As you can see, both actor() and film() return 0-element Arrays. That's because none of these classes has any objects yet. Let's see what happens if we add some. Run:","category":"page"},{"location":"#","page":"Home","title":"Home","text":"julia> objects = [\n\t[\"actor\", \"Phoenix\"], \n\t[\"actor\", \"Johansson\"], \n\t[\"film\", \"Her\"], \n\t[\"film\", \"Joker\"]\n];\n\njulia> import_and_commit(db_map; objects=objects)\n\njulia> using_spinedb(url)\n\njulia> actor()\n2-element Array{Union{Int64, T} where T<:SpineInterface.AbstractObject,1}:\n Phoenix\n Johansson\n\njulia> film()\n2-element Array{Union{Int64, T} where T<:SpineInterface.AbstractObject,1}:\n Her\n Joker\n\njulia> film(:Her)\nHer\n\njulia> typeof(ans)\nObject\n","category":"page"},{"location":"#","page":"Home","title":"Home","text":"Things got a little bit more interesting.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"Now let's see what happens if we add relationships:","category":"page"},{"location":"#","page":"Home","title":"Home","text":"julia> relationship_classes = [[\"actor__film\", [\"actor\", \"film\"]]];\n\njulia> relationships = [\n\t[\"actor__film\", [\"Phoenix\", \"Joker\"]], \n\t[\"actor__film\", [\"Phoenix\", \"Her\"]], \n\t[\"actor__film\", [\"Johansson\", \"Her\"]]\n];\n\njulia> import_and_commit(\n\tdb_map; relationship_classes=relationship_classes, relationships=relationships\n)\n","category":"page"},{"location":"#","page":"Home","title":"Home","text":"The above will add a relationship class called \"actor__film\"  between the \"actor\" and \"film\" object classes, and a couple of relationships of that class. Now let's see the effect of calling using_spinedb:","category":"page"},{"location":"#","page":"Home","title":"Home","text":"julia> using_spinedb(url)\n\njulia> actor__film()\n3-element Array{NamedTuple{K,V} where V<:Tuple{Vararg{Union{Int64, T} where T<:SpineInterface.AbstractObject,N} where N} where K,1}:\n (actor = Phoenix, film = Her)\n (actor = Johansson, film = Her)\n (actor = Phoenix, film = Joker)\n\njulia> actor__film(actor=actor(:Johansson))\n1-element Array{Object,1}:\n Her\n\njulia> actor__film(film=film(:Her))\n2-element Array{Object,1}:\n Johansson\n Phoenix\n","category":"page"},{"location":"#","page":"Home","title":"Home","text":"Finally, let's add some parameters and some values to database:","category":"page"},{"location":"#","page":"Home","title":"Home","text":"julia> object_parameters = [[\"film\", \"release_year\"]];\n\njulia> relationship_parameters = [[\"actor__film\", \"character_name\"]];\n\njulia> object_parameter_values = [\n\t[\"film\", \"Joker\", \"release_year\", 2019],\n\t[\"film\", \"Her\", \"release_year\", 2013],\n];\n\njulia> relationship_parameter_values = [\n\t[\"actor__film\", [\"Phoenix\", \"Joker\"], \"character_name\", \"Arthur\"], \n\t[\"actor__film\", [\"Phoenix\", \"Her\"], \"character_name\", \"Theodore\"], \n\t[\"actor__film\", [\"Johansson\", \"Her\"], \"character_name\", \"Samantha\"]\n];\n\njulia> import_and_commit(\n\tdb_map;\n\tobject_parameters=object_parameters, \n\trelationship_parameters=relationship_parameters, \n\tobject_parameter_values=object_parameter_values,\n\trelationship_parameter_values=relationship_parameter_values\n)","category":"page"},{"location":"#","page":"Home","title":"Home","text":"And after calling using_spinedb:","category":"page"},{"location":"#","page":"Home","title":"Home","text":"julia> using_spinedb(url)\r\n\r\njulia> release_year(film=film(:Joker))\r\n2019\r\n\r\njulia> release_year(film=film(:Her))\r\n2013\r\n\r\njulia> character_name(film=film(:Joker), actor=actor(:Phoenix))\r\n:Arthur\r\n\r\njulia> character_name(actor=actor(:Johansson), film=film(:Her))\r\n:Samantha\r\n\r\njulia> character_name(actor=actor(:Johansson), film=film(:Joker))\r\nERROR: parameter character_name is not specified for argument(s) :actor => Johansson:film => Joker","category":"page"},{"location":"#Library-outline-1","page":"Home","title":"Library outline","text":"","category":"section"},{"location":"#","page":"Home","title":"Home","text":"Pages = [\"library.md\"]\r\nDepth = 3","category":"page"},{"location":"library/#Library-1","page":"Library","title":"Library","text":"","category":"section"},{"location":"library/#","page":"Library","title":"Library","text":"Documentation for SpineInterface.jl.","category":"page"},{"location":"library/#Contents-1","page":"Library","title":"Contents","text":"","category":"section"},{"location":"library/#","page":"Library","title":"Library","text":"Pages = [\"library.md\"]\r\nDepth = 3","category":"page"},{"location":"library/#Index-1","page":"Library","title":"Index","text":"","category":"section"},{"location":"library/#","page":"Library","title":"Library","text":"","category":"page"},{"location":"library/#Types-1","page":"Library","title":"Types","text":"","category":"section"},{"location":"library/#","page":"Library","title":"Library","text":"ObjectLike\r\nObject\r\nTimeSlice\r\nAnything","category":"page"},{"location":"library/#SpineInterface.Object","page":"Library","title":"SpineInterface.Object","text":"Object\n\nA type for representing an object in a Spine db.\n\n\n\n\n\n","category":"type"},{"location":"library/#SpineInterface.TimeSlice","page":"Library","title":"SpineInterface.TimeSlice","text":"TimeSlice\n\nA type for representing a slice of time.\n\n\n\n\n\n","category":"type"},{"location":"library/#SpineInterface.Anything","page":"Library","title":"SpineInterface.Anything","text":"Anything\n\nA type with no fields that is the type of anything.\n\n\n\n\n\n","category":"type"},{"location":"library/#Functions-1","page":"Library","title":"Functions","text":"","category":"section"},{"location":"library/#","page":"Library","title":"Library","text":"using_spinedb(::String)\r\nObjectClass()\r\nRelationshipClass()\r\nParameter()\r\nindices(::Parameter)\r\nTimeSlice(::DateTime, ::DateTime)\r\nduration(::TimeSlice)\r\nbefore(::TimeSlice, ::TimeSlice)\r\niscontained(::TimeSlice, ::TimeSlice)\r\noverlaps(::TimeSlice, ::TimeSlice)\r\noverlap_duration(::TimeSlice, ::TimeSlice)\r\nt_lowest_resolution(::Array{TimeSlice,1})\r\nt_highest_resolution(::Array{TimeSlice,1})\r\nwrite_parameters(::Any, ::String)","category":"page"},{"location":"library/#SpineInterface.using_spinedb-Tuple{String}","page":"Library","title":"SpineInterface.using_spinedb","text":"using_spinedb(db_url::String, mod=@__MODULE__; upgrade=false)\n\nExtend module mod with convenience functions to access the contents of the Spine db at the given RFC-1738 url. If upgrade is true, then the database is upgraded to the latest revision.\n\nSee ObjectClass(), RelationshipClass(), and Parameter() for details on how to call the convenience functors.\n\n\n\n\n\n","category":"method"},{"location":"library/#SpineInterface.ObjectClass-Tuple{}","page":"Library","title":"SpineInterface.ObjectClass","text":"(<oc>::ObjectClass)(;<keyword arguments>)\n\nAn Array of Object instances corresponding to the objects in class oc.\n\nArguments\n\nFor each parameter associated to oc in the database there is a keyword argument named after it. The purpose is to filter the result by specific values of that parameter.\n\nExamples\n\njulia> using SpineInterface;\n\njulia> url = \"sqlite:///\" * joinpath(dirname(pathof(SpineInterface)), \"..\", \"examples/data/example.sqlite\");\n\njulia> using_spinedb(url)\n\njulia> sort(node())\n5-element Array{Object,1}:\n Dublin\n Espoo\n Leuven\n Nimes\n Sthlm\n\njulia> commodity(state_of_matter=:gas)\n1-element Array{Object,1}:\n wind\n\n\n\n\n\n\n","category":"method"},{"location":"library/#SpineInterface.RelationshipClass-Tuple{}","page":"Library","title":"SpineInterface.RelationshipClass","text":"(<rc>::RelationshipClass)(;<keyword arguments>)\n\nAn Array of Object tuples corresponding to the relationships of class rc.\n\nArguments\n\nFor each object class in rc there is a keyword argument named after it. The purpose is to filter the result by an object or list of objects of that class, or to accept all objects of that class by specifying anything for this argument.\n_compact::Bool=true: whether or not filtered object classes should be removed from the resulting tuples.\n_default=[]: the default value to return in case no relationship passes the filter.\n\nExamples\n\njulia> using SpineInterface;\n\njulia> url = \"sqlite:///\" * joinpath(dirname(pathof(SpineInterface)), \"..\", \"examples/data/example.sqlite\");\n\njulia> using_spinedb(url)\n\njulia> sort(node__commodity())\n5-element Array{NamedTuple,1}:\n (node = Dublin, commodity = wind)\n (node = Espoo, commodity = wind)\n (node = Leuven, commodity = wind)\n (node = Nimes, commodity = water)\n (node = Sthlm, commodity = water)\n\njulia> node__commodity(commodity=:water)\n2-element Array{Object,1}:\n Nimes\n Sthlm\n\njulia> node__commodity(node=(:Dublin, :Espoo))\n1-element Array{Object,1}:\n wind\n\njulia> sort(node__commodity(node=anything))\n2-element Array{Object,1}:\n water\n wind\n\njulia> sort(node__commodity(commodity=:water, _compact=false))\n2-element Array{NamedTuple,1}:\n (node = Nimes, commodity = water)\n (node = Sthlm, commodity = water)\n\njulia> node__commodity(commodity=:gas, _default=:nogas)\n:nogas\n\n\n\n\n\n\n","category":"method"},{"location":"library/#SpineInterface.Parameter-Tuple{}","page":"Library","title":"SpineInterface.Parameter","text":"(<p>::Parameter)(;<keyword arguments>)\n\nThe value of parameter p for a given object or relationship.\n\nArguments\n\nFor each object class associated with p there is a keyword argument named after it. The purpose is to retrieve the value of p for a specific object.\nFor each relationship class associated with p, there is a keyword argument named after each of the object classes involved in it. The purpose is to retrieve the value of p for a specific relationship.\ni::Int64: a specific index to retrieve in case of an array value (ignored otherwise).\nt::TimeSlice: a specific time-index to retrieve in case of a time-varying value (ignored otherwise).\ninds: indexes for navigating a Map (ignored otherwise). Tuples correspond to navigating nested Maps.\n_strict::Bool: whether to raise an error or return nothing if the parameter is not specified for the given arguments.\n\nExamples\n\njulia> using SpineInterface;\n\njulia> url = \"sqlite:///\" * joinpath(dirname(pathof(SpineInterface)), \"..\", \"examples/data/example.sqlite\");\n\njulia> using_spinedb(url)\n\njulia> tax_net_flow(node=:Sthlm, commodity=:water)\n4\n\njulia> demand(node=:Sthlm, i=1)\n21\n\n\n\n\n\n\n","category":"method"},{"location":"library/#SpineInterface.indices-Tuple{Parameter}","page":"Library","title":"SpineInterface.indices","text":"indices(p::Parameter; kwargs...)\n\nAn iterator over all objects and relationships where the value of p is different than nothing.\n\nArguments\n\nFor each object class where p is defined, there is a keyword argument named after it; similarly, for each relationship class where p is defined, there is a keyword argument named after each object class in it. The purpose of these arguments is to filter the result by an object or list of objects of an specific class, or to accept all objects of that class by specifying anything for the corresponding argument.\n\nExamples\n\njulia> using SpineInterface;\n\njulia> url = \"sqlite:///\" * joinpath(dirname(pathof(SpineInterface)), \"..\", \"examples/data/example.sqlite\");\n\njulia> using_spinedb(url)\n\njulia> collect(indices(tax_net_flow))\n1-element Array{NamedTuple{(:commodity, :node),Tuple{Object,Object}},1}:\n (commodity = water, node = Sthlm)\n\njulia> collect(indices(demand))\n5-element Array{Object,1}:\n Nimes\n Sthlm\n Leuven\n Espoo\n Dublin\n\n\n\n\n\n\n","category":"method"},{"location":"library/#SpineInterface.TimeSlice-Tuple{DateTime,DateTime}","page":"Library","title":"SpineInterface.TimeSlice","text":"TimeSlice(start::DateTime, end_::DateTime)\n\nConstruct a TimeSlice with bounds given by start and end_.\n\n\n\n\n\n","category":"method"},{"location":"library/#SpineInterface.duration-Tuple{TimeSlice}","page":"Library","title":"SpineInterface.duration","text":"duration(t::TimeSlice)\n\nThe duration of time slice t.\n\n\n\n\n\n","category":"method"},{"location":"library/#SpineInterface.before-Tuple{TimeSlice,TimeSlice}","page":"Library","title":"SpineInterface.before","text":"before(a::TimeSlice, b::TimeSlice)\n\nDetermine whether the end point of a is exactly the start point of b.\n\n\n\n\n\n","category":"method"},{"location":"library/#SpineInterface.iscontained-Tuple{TimeSlice,TimeSlice}","page":"Library","title":"SpineInterface.iscontained","text":"iscontained(b, a)\n\nDetermine whether b is contained in a.\n\n\n\n\n\n","category":"method"},{"location":"library/#SpineInterface.overlaps-Tuple{TimeSlice,TimeSlice}","page":"Library","title":"SpineInterface.overlaps","text":"overlaps(a::TimeSlice, b::TimeSlice)\n\nDetermine whether a and b overlap.\n\n\n\n\n\n","category":"method"},{"location":"library/#SpineInterface.overlap_duration-Tuple{TimeSlice,TimeSlice}","page":"Library","title":"SpineInterface.overlap_duration","text":"overlap_duration(a::TimeSlice, b::TimeSlice)\n\nThe duration of the period where a and b overlap.\n\n\n\n\n\n","category":"method"},{"location":"library/#SpineInterface.t_lowest_resolution-Tuple{Array{TimeSlice,1}}","page":"Library","title":"SpineInterface.t_lowest_resolution","text":"t_lowest_resolution(t_iter)\n\nReturn an Array containing only time slices from t_iter that aren't contained in any other.\n\n\n\n\n\n","category":"method"},{"location":"library/#SpineInterface.t_highest_resolution-Tuple{Array{TimeSlice,1}}","page":"Library","title":"SpineInterface.t_highest_resolution","text":"t_highest_resolution(t_iter)\n\nReturn an Array containing only time slices from t_iter that do not contain any other.\n\n\n\n\n\n","category":"method"},{"location":"library/#Constants-1","page":"Library","title":"Constants","text":"","category":"section"},{"location":"library/#","page":"Library","title":"Library","text":"anything","category":"page"},{"location":"library/#SpineInterface.anything","page":"Library","title":"SpineInterface.anything","text":"anything\n\nThe singleton instance of type Anything, used to specify all-pass filters in calls to RelationshipClass().\n\n\n\n\n\n","category":"constant"}]
}
