using Test, Jtb

@testset "math" begin
    @test isequal( map_lastn(sum, [1.0,2.0,3.0,NaN,5.0,6.0,7.0], 3), [ NaN; NaN; NaN; 6.0; 6.0; 10.0; 14.0 ] )
end
