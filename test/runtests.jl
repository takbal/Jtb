using Test, Jtb, Dates, AxisKeys, Random

Random.seed!(123456)

@testset "math" begin
    @test isequal( map_lastn(sum, [1.0,2.0,3.0,NaN,5.0,NaN,7.0], 3), [ NaN; NaN; NaN; 6.0; 6.0; 10.0; 10.0 ] )
end

@testset "stats" begin
    indices, lbounds, ubounds = fractiles([5, 4, 8, missing, NaN, 0, 8], 3; ignore=ismissingornanorzero)
    @test isequal( indices, [[2], [1, 3], [7]] )
    @test isequal( lbounds, [4.0, 5.0, 8.0] )
    @test isequal( ubounds, [4.0, 8.0, 8.0] )
end

@testset "array" begin
    @test isequal(
        propfill!( isnan, [ NaN NaN ; 1 2 ; NaN NaN ; 3 4 ]; dim=1 ),
        [ NaN NaN ; 1 2 ; 1 2 ; 3 4] )
    @test isequal(
        anyslice(isnan, cat([NaN 1; NaN NaN], [ NaN 1 ; NaN NaN ], dims=3); dim=1),
        BitVector([1, 1]) )
    @test isequal(
        allslice(isnan, cat([NaN 1; NaN NaN], [ NaN 1 ; NaN NaN ], dims=3); dim=1),
        BitVector([0, 1]) )
end

@testset "datetime" begin
    @test isequal(
        get_interval_indices( Array(DateTime(2014,1,29):Hour(1):DateTime(2014,2,3)), Day),
        ([1, 25, 49, 73, 97, 121], [24, 48, 72, 96, 120, 121]))
    @test isequal(
        shortstring(canonicalize(Second(123456))),
        "1d:10h:17m:36s")
end

@testset "julia" begin
    oldstd = stdout
    redirect_stdout(devnull)
    out = typeinfo(String)
    redirect_stdout(oldstd)
    @test isequal( out, nothing )
end

@testset "karray" begin
    mat1 = KeyedArray("example_matrix.csv", type=Array{Int, 2}, dimnames=["rows", "cols"], keycols=[1,4])
    mat2 = KeyedArray( [ 1 2 ; 3 4 ; 5 6 ], rows=["r1,+", "r2x,+", "r2x,-"], cols = ["col2", "col3"])
    @test isequal( mat1, mat2 )
    mat3 = KeyedArray([ 2 ; 1 ; 3 ], keys=[5 ; 4 ; 6])
    d1 = Dict(4=>1, 5=>2, 6=>3)
    @test isequal( convert(Dict, mat3), d1)
    @test isequal( KeyedArray(d1), mat3 )
    mat3f = KeyedArray([ 2.0 ; 1.0 ; 3.0 ], keys=[5 ; 4 ; 6])
    @test isequal( convert_eltype(Float64, mat3), mat3f )
    mat4 = KeyedArray(Matrix{Int64}([ 2 1 3 ])', keys=[5 ; 4 ; 6], foo=["bar"])
    @test isequal( extdim(mat3, :foo, ["bar"]), mat4 )
    mat5 = KeyedArray( [ 0 0 ; 2 0 ], rows=["foo", "r1,+"], cols = ["col3", "bar"])
    @test isequal( sync_to(Dict(:rows => ["foo","r1,+"], :cols => ["col3", "bar"]), mat1, fillval = 0), mat5 )
    @test isequal( sync_to(mat5, mat1, fillval = 0), mat5 )
    mat6, mat7 = sync(mat1, mat5, fillval=0, type=:inner, dims=:cols)
    @test isequal( mat6, KeyedArray( Matrix{Int64}([2  4  6])', rows=["r1,+", "r2x,+", "r2x,-"], cols=["col3"]) )
    @test isequal( mat7, KeyedArray( Matrix{Int64}([0  2])', rows=["foo", "r1,+"], cols=["col3"]) )
    mat8, mat9 = sync(mat1, mat5, fillval=0, type=:outer, dims=:cols)
    @test isequal( mat8, KeyedArray( Matrix{Int64}([ 0 1 2 ; 0 3 4 ; 0 5 6 ]), rows=["r1,+", "r2x,+", "r2x,-"], cols=["bar", "col2", "col3"]) )
    @test isequal( mat9, KeyedArray( Matrix{Int64}([ 0 0 0 ; 0 0 2 ]), rows=["foo", "r1,+"], cols=["bar", "col2", "col3"]) )
    @test isequal( diff(mat1; dims=1), KeyedArray( Matrix{Int64}([ 2 2 ; 2 2 ]), rows=["r2x,+", "r2x,-"], cols=["col2", "col3"]) )
    timedatemat = wrapdims([1 2 3 ; 4 5 6 ;;; 7 8 9 ; 10 11 12], times=[Time(9,00);Time(10,00)], dates=[Date(2022,1,1);Date(2022,1,2);Date(2022,1,4)], foobar=["foo";"bar"])
    timedatemat = transform_keys(d->d+Day(2), timedatemat; dim=:dates )
    timedatemat = transform_keys(t->t-Hour(1), timedatemat; dim=:times )
    @test isequal( timedatemat, wrapdims([1 2 3 ; 4 5 6 ;;; 7 8 9 ; 10 11 12], times=[Time(8,00);Time(9,00)], dates=[Date(2022,1,3);Date(2022,1,4);Date(2022,1,6)], foobar=["foo";"bar"]) )
    timedatemat = wrapdims([1 2 3 ; 4 5 6], times=[Time(9,00);Time(10,00)], dates=[Date(2022,1,1);Date(2022,1,2);Date(2022,1,4)])
    timedatemat = shift_keys(1, timedatemat; dim=:dates)
    @test isequal( timedatemat, wrapdims([1 2 ; 4 5 ], times=[Time(9,00);Time(10,00)], dates=[Date(2022,1,2);Date(2022,1,4)]))
end
