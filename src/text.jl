using JSON

boldify(s::AbstractString) = "<b>" * s * "</b>"
italicify(s::AbstractString) = "<i>" * s * "</i>"

printjson(X) = print(json(X,4))
