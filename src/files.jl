"""
    getdir(path::AbstractString, pattern::Regex = r"";
        dirs::Bool = true,
        files::Bool = true,
        recursive::Bool = false,
        join::Bool = true,
        normalize::Bool = true,
        absolute::Bool = false,
        sort::Bool = true,
        topdown::Bool = true,
        hidden::Bool = false,
        follow_symlinks::Bool = false)::String[]

Returns a list of files or dirs found below a path that match the regexp pattern.

(It is a mix of `readdir()` and `walkdir()` as none of them can do what really needed.)

Keyword parameters:
-------------------

    dirs:
include directories

    files:
include files

    recursive:
walk subdirectories as well

    join:
add the searched path in front of the filename

    normalize:
normalise filenames

    absolute:
generate absolute paths

    sort:
sort outgoing filenames

    topdown:
if recursive, walk top-down

    hidden:
include files/directories starting with .

    follow_symlinks:
if recursive, follow symlinks
"""
function getdir(path::AbstractString, pattern::Regex = r"";
    dirs::Bool = true,
    files::Bool = true,
    recursive::Bool = false,
    normalize::Bool = true,
    absolute::Bool = false,
    join::Bool = true,
    sort::Bool = true,
    topdown::Bool = true,
    hidden::Bool = false,
    follow_symlinks::Bool = false)::Array{String}

    @assert !absolute || join "absolute cannot be used without join"

    out = String[]

    if recursive
        for (root, ds, fs) in walkdir(path; topdown, follow_symlinks)
            if !join
                root = ""
            end
            if dirs
                for dir in ds
                    push!(out, joinpath(root, dir))
                end
            end
            if files
                for file in fs
                    push!(out, joinpath(root, file))
                end
            end
        end
    else
        for f in readdir(path; join, sort)
            truepath = join ? f : joinpath(path, f)
            if dirs && isdir(truepath)
                push!(out, f)
            end
            if files && isfile(truepath)
                push!(out, f)
            end
        end
    end

    for i in eachindex(out)
        if absolute
            out[i] = abspath(out[i])
        end
        if normalize
            out[i] = normpath(out[i])
        end
    end

    if sort
        sort!(out)
    end

    if pattern != r""
        out = [ x for x in out if match(pattern,x) !== nothing ]
    end

    if !hidden
        out = [ x for x in out if !any( startswith.(splitpath(x), '.') ) ]
    end

    return out

end


"""
get_common_path_prefix(paths::AbstractVector{T}) where T <:AbstractString

Returns the common prefix (the path to the deepest common directory) of the paths given.
Returns nothing if no such thing was found.
"""
function get_common_path_prefix(paths::AbstractVector{T})::Union{String,Nothing} where T <:AbstractString

    # cache splitted versions
    splitted = Vector{Vector{String}}()
    for f in paths
        push!(splitted, splitpath(f))
    end

    first_different_dir_idx = 0
    while true
        first_different_dir_idx += 1
        if length(splitted[1]) < first_different_dir_idx
            break
        end
        found_different = false
        for idx in 2:length(paths)
            if length(splitted[idx]) < first_different_dir_idx || splitted[1][first_different_dir_idx] != splitted[idx][first_different_dir_idx]
                found_different = true
                break
            end
        end
        if found_different
            break
        end
    end

    if first_different_dir_idx == 1
        return nothing
    end

    return joinpath(splitted[1][1:first_different_dir_idx-1])

end
