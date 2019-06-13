using PyCall

python = PyCall.pyprogramname
run(`$python -m pip --user install 'git+https://github.com/Spine-project/Spine-Database-API#dev'`)
