using Documenter, SpineInterface, PyCall, Dates

pages=[
    "Home" => "index.md",
    "Tutorials" => Any[
        "Tutorial spine database" => joinpath("tutorials", "tutorial_spine_database.md"),
        "Tutorial SpineOpt database" => joinpath("tutorials", "tutorial_spineopt_database.md")
    ],
    "Library" => "library.md"
]

makedocs(
    sitename="SpineInterface.jl",
    format=Documenter.HTML(prettyurls=get(ENV, "CI", nothing) == "true"),
    pages=pages,
)

deploydocs(repo="github.com/Spine-tools/SpineInterface.jl.git", versions=["stable" => "v^", "v#.#"])