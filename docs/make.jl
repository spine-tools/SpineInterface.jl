using Documenter, SpineInterface, PyCall, Dates
import MetaGraphsNext

pages=[
    "Home" => "index.md",
    "Tutorials" => Any[
        "SpineInterface basics" => joinpath("tutorials", "basics.md"),
        "Classic interface basics" => joinpath("tutorials", "tutorial_spine_database.md"),
        "Classic interface with SpineOpt database" => joinpath("tutorials", "tutorial_spineopt_database.md")
    ],
    "Library" => "library.md"
]

makedocs(
    sitename="SpineInterface.jl",
    format=Documenter.HTML(prettyurls=get(ENV, "CI", nothing) == "true"),
    pages=pages,
)

deploydocs(repo="github.com/spine-tools/SpineInterface.jl.git", versions=["stable" => "v^", "v#.#"])
