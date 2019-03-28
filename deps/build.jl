using PyCall

python = PyCall.pyprogramname
run(`$python -m pip install 'git+https://github.com/Spine-project/Spine-Database-API#dev'`)
