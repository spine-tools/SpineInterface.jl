using Pkg
bin_dir = Base.Filesystem.dirname(@__FILE__)
docs_dir = Base.Filesystem.joinpath(bin_dir, "..", "docs")
Pkg.activate(docs_dir)
package_dir = Base.Filesystem.joinpath(bin_dir, "..")
Pkg.develop(path=package_dir)
Pkg.instantiate()
include(Base.Filesystem.joinpath(docs_dir, "make.jl"))
