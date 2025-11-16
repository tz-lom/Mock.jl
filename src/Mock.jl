module Mock

export with_mocked, SubstituteMock, @original

abstract type AbstractMock end

abstract type AbstractActiveMock end

function activate(::AbstractMock) end

function deactivate(::AbstractActiveMock) end

const ORIGINALS = IdDict{Any,Any}()

function register_original(method, original::Core.CodeInstance, substitute)
    ORIGINALS[substitute] = (method => original)
end

function deregister_original(substitute)
    delete!(ORIGINALS, substitute)
end

macro original(args...)
    esc(
        # Expr(:macrocall, Symbol("@static"),
        :(
            if (call = get($ORIGINALS, var"#self#", missing)) !== missing

                invoke(call[1], call[2], $(args...))
            else
                error("@original can be called only from active mock function")
            end
        )
        # )
    )
end

function match_signature(left, right, check_kwargs=true)
    return Base.unwrap_unionall(left.sig).types[2:end] == Base.unwrap_unionall(right.sig).types[2:end] &&
           (!check_kwargs || (Base.kwarg_decl(left) == Base.kwarg_decl(right)))
end

match_signature(sig) = Base.Fix2(match_signature, sig)

function setup_mock(call, mock)
    # get mock signature
    @assert length(methods(mock)) == 1 "Can be only one mock"
    replacement = methods(mock)[1]

    # check if call can be overloaded (exact signature match)
    orig_idx = findfirst(match_signature(replacement), methods(call))
    @assert !isnothing(orig_idx) "Can't find original call to mock (signatures must be exactly same)"
    orig = methods(call)[orig_idx]

    sig = Base.unwrap_unionall(orig.sig).types[2:end]

    # now we need to build signature for proxy
    args = Any[:($(Symbol("arg_", idx))::$type) for (idx, type) = enumerate(sig)]  # @todo: keep argument parameter names to make it pretty
    params = Any[Symbol("arg_", idx) for idx = 1:length(sig)]
    if !isempty(Base.kwarg_decl(orig)) # because kwargs are not part of dispatch, we capture any amount and pass downstairs
        pushfirst!(args, Expr(:parameters, :(kwargs...)))
        pushfirst!(params, Expr(:parameters, :(kwargs...)))
    end
    pushfirst!(args, Expr(:(.), orig.module, QuoteNode(orig.name)))
    pushfirst!(params, mock)

    # Capture original method instance for @original
    mi = Base.method_instance(call, Tuple{sig...})
    precompile(mi) # otherwise cache may not exist yet

    setup = Expr(:(=), Expr(:call, args...), Expr(:call, params...))

    eval(setup)

    overload = methods(call)[orig_idx]
    @assert overload != orig "Instead of replacing target function did something else, don't rely on following calls"
    @assert match_signature(overload, replacement) "Corrupted signature on replacement"

    register_original(call, mi.cache, mock) # delay registration to make sure all errors are caught before
    return orig, overload
end

function finalize_mock(orig, overload)
    f = overload.sig.types[1]
    Base.delete_method(overload)

    check_restore() = Base.invokelatest(() -> orig in methods(getproperty(orig.module, orig.name)))

    return orig, f

    @assert check_restore() "Failed to restore function $f"
end


struct SubstituteMock <: AbstractMock
    target
    mock
end

struct ActiveSubstituteMock <: AbstractActiveMock
    original
    replaced
end

function activate(subst::SubstituteMock)
    original, replaced = setup_mock(subst.target, subst.mock)
    ActiveSubstituteMock(original, replaced)
end

activate(subst::Pair{<:Function,<:Function}) = activate(SubstituteMock(subst.first, subst.second))

function deactivate(subst::ActiveSubstituteMock)
    finalize_mock(subst.original, subst.replaced)
end


function with_mocked(code, mocks...)
    active = AbstractActiveMock[]

    function fin()
        for mock in active
            try
                deactivate(mock)
            catch exception
                @error "Mock $mock wasn't finalized properly, function behavior may be corrupted" exception
            end
        end
    end

    for mock in mocks
        try
            push!(active, activate(mock))
        catch
            @error "Mock $mock can't be activated, terminating execution"
            fin()
            rethrow()
        end
    end

    try
        Base.invokelatest(code)
    finally
        fin()
    end
end

end # module Mock
