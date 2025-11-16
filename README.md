# Mock.jl

A lightweight Julia package for temporarily replacing function implementations.

## Key Features

- **Non-intrusive mocking**: You can mock **ANY** method from **ANY** package without any prerequisites.
- **Reversible**: Mock is temporary and is fully reverted in the end.
- **Partial mocking**: You select which invariants of `Method` shall be mocked.
- **Zero cost**: Injected mocks have exactly same performance as if it was original code.
- **No surprises**: Extensive checks ensure that no mistakes are made in setup and that mock will behave as you expect.

## Usage

> This API is unstable and is subject to change.

Mock.jl provides a simple way to temporarily replace function implementations for testing purposes.

```julia
using Mock

# Define a mock function with the same signature as the target
mock_func(x::Real) = 42

with_mocked(SubstituteMock(sin, mock_func)) do
    # Mock is active only here
    @test sin(0) == 42
end

@test sin(0) == 0
```

## License

See LICENSE file for details.
