using PyCall

try
    pyimport("spinedb_api")
catch err
    if err isa PyCall.PyError
        error(
            """
            The required Python package `spinedb_api` could not be found in the current Python environment

                $(PyCall.pyprogramname)
            """
        )
    else
        rethrow()
    end
end