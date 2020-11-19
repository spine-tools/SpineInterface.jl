using PyCall

try
    pyimport("spinedb_api")
catch err
    if err isa PyCall.PyError
        error("""
              The required Python package `spinedb_api` could not be found in the current Python environment

                  $(PyCall.pyprogramname)
                  
              Please execute      

                  "$(PyCall.pyprogramname)" -m pip install 'git+https://github.com/Spine-project/Spine-Database-API'
                  
              to install the latest version.
              """)
    else
        rethrow()
    end
end
