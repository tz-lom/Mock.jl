using Mock
using Test


@testset begin

    function fake_sin(x::Real)
        @warn "sin" x
        return 2  # lol
    end

    with_mocked(SubstituteMock(sin, fake_sin)) do
        @test_warn "sin" sin(0)
        @test sin(0) == 2
    end

    @test_nowarn sin(0)
    @test sin(0) == 0

end