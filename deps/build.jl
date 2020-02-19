using PyCall

try
    pyimport("spinedb_api")
catch err
    if err isa PyCall.PyError
        error(
            """
            The required Python package `spinedb_api` could not be found in the current Python environment

                $(PyCall.pyprogramname)

            You can fix this in two different ways:

            A. Install `spinedb_api` in the current Python environment; open a terminal (command prompt on Windows) and run

                $(PyCall.pyprogramname) -m pip install --user 'git+https://github.com/Spine-project/Spine-Database-API'

            B. Switch to another Python environment that has `spinedb_api` installed; from Julia, run 

                ENV["PYTHON"] = "... path of the python executable ..."
                Pkg.build("PyCall")

            And restart Julia.
            """
        )
    else
        rethrow()
    end
end