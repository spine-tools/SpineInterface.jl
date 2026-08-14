using Documenter, SpineInterface, PyCall, Dates
import MetaGraphsNext

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

deploydocs(repo="github.com/spine-tools/SpineInterface.jl.git", versions=["stable" => "v^", "v#.#"])
