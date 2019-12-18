using PyCall

python = PyCall.pyprogramname
run(`$python -m pip install --user 'git+https://github.com/Spine-project/Spine-Database-API'`)
