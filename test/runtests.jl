using Test, Jtb

@testset "math" begin
    @test isequal( map_lastn(sum, [1.0,2.0,3.0,NaN,5.0,6.0,7.0], 3), [ NaN; NaN; NaN; 6.0; 6.0; 10.0; 14.0 ] )
end

@testset "stats" begin
    indices, lbounds, ubounds = fractiles([5, 4, 8, missing, NaN, 0, 8], 3; ignore=ismissingornanorzero)
    @test isequal( indices, [[2], [1, 3], [7]] )
    @test isequal( lbounds, [4.0, 5.0, 8.0] )
    @test isequal( ubounds, [4.0, 8.0, 8.0] )
end
