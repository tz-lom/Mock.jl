using Mock
using Test

mock_me() = :orig1
mock_me(::Int) = orig3
mock_me(::Int, ::Int=4) = :orig2


call_me() = mock_me(4)

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


    mocked(::Int, ::Int) = :mocked1
    # mocked(::Int) = :mocked2


    with_mocked(SubstituteMock(mock_me, mocked)) do
        @test mock_me(1) == :mocked1
        @test call_me() == :mocked1
        # @test mock_me(1, 1) == :mocked1
    end
    @test call_me() == :orig2

end