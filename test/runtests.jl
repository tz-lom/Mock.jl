using Mock
using Test

mock_me() = :orig1
mock_me(::Int) = orig3
mock_me(::Int, ::Int=4) = :orig2


call_me() = mock_me(4)


mocked(::Int, ::Int) = :mocked1

function mocked2(a::Int, b::Int)

    Symbol(
        :overload_,
        # nameof(var"#self#")
        @original(a, b)
    )
end


@testset begin

    function fake_sin(x::Real)
        @warn "sin" x
        return 2  # lol
    end

    with_mocked(SubstituteMock(sin, fake_sin)) do
        @test_warn "sin" @test sin(0) == 2
    end

    @test_nowarn sin(0)
    @test sin(0) == 0

    # mocked(::Int) = :mocked2


    with_mocked(SubstituteMock(mock_me, mocked)) do
        @test mock_me(1) == :mocked1
        @test call_me() == :mocked1
        # @test mock_me(1, 1) == :mocked1

    end
    @test call_me() == :orig2

    with_mocked(mock_me => mocked2) do
        @test call_me() == :overload_orig2
        # @test mock_me(1, 1) == :mocked1
    end


    function fake_sin2(x::Float16)
        return 42 + @original(x)
    end

    with_mocked(sin => fake_sin2) do
        @test sin(Float16(0)) == Float16(42)
        @test sin(Float16(0)) == Float16(42)
        @test sin(Float16(pi / 2)) == Float16(43)
        @test sin(Float16(pi / 2)) == Float16(43)

    end

    @test sin(Float16(0)) == Float16(0)
    @test sin(Float16(pi / 2)) == Float16(1)

end