reference_path(filename) = joinpath(dirname(@__FILE__), "reference", "$(filename).txt")

function test_reference_impl{T<:Colorant}(filename, img::AbstractArray{T})
    res = ImageInTerminal.encodeimg(ImageInTerminal.SmallBlocks(), ImageInTerminal.TermColor256(), img, 20, 40)[1]
    test_reference_impl(filename, res)
end

function test_reference_impl{T<:String}(filename, actual::AbstractArray{T})
    try
        reference = replace.(readlines(reference_path(filename)), ["\n"], [""])
        try
            @assert reference == actual # to throw error
            @test true # to increase test counter if reached
        catch # test failed
            println("Test for \"$filename\" failed.")
            println("- REFERENCE -------------------")
            println.(reference)
            println("-------------------------------")
            println("- ACTUAL ----------------------")
            println.(actual)
            println("-------------------------------")
            if isinteractive()
                print("Replace reference with actual result? [y/n] ")
                answer = first(readline())
                if answer == 'y'
                    write(reference_path(filename), join(actual, "\n"))
                end
            else
                error("You need to run the tests interactively with 'include(\"test/runtests.jl\")' to update reference images")
            end
        end
    catch ex
        if isa(ex, SystemError) # File doesn't exist
            println("Reference file for \"$filename\" does not exist.")
            println("- NEW CONTENT -----------------")
            println.(actual)
            println("-------------------------------")
            if isinteractive()
                print("Create reference file with above content? [y/n] ")
                answer = first(readline())
                if answer == 'y'
                    write(reference_path(filename), join(actual, "\n"))
                end
            else
                error("You need to run the tests interactively with 'include(\"test/runtests.jl\")' to create new reference images")
            end
        else
            throw(ex)
        end
    end
end

# using a macro looks more consistent
macro test_reference(filename, expr)
    esc(:(test_reference_impl($filename, $expr)))
end

# --------------------------------------------------------------------

@testset "single op" begin
    img = @inferred Augmentor.augment(rect, (Rotate90(),))
    @test typeof(img) <: Array
    @test eltype(img) <: eltype(rect)
    @test img == rotl90(rect)
end

op = (Rotate180(),Crop(5:200,200:500),Rotate90(1),Crop(1:250, 1:150))
@testset "$(str_showcompact(ops))" begin
    wv = @inferred Augmentor._augment(camera, op)
    @test typeof(wv) <: SubArray
    @test typeof(wv.indexes) <: Tuple{Vararg{IdentityRange}}
    @test typeof(parent(wv)) <: InvWarpedView
    @test parent(parent(wv)).itp.coefs === camera
    @test_reference "rot_crop_either_crop" wv
    img = @inferred augment(camera, op)
    @test img == parent(copy(wv))
    @test typeof(img) <: Array
    @test eltype(img) <: eltype(camera)
    @test_reference "rot_crop_either_crop" img
end

op = (Rotate180(),Crop(5:200,200:500),Rotate90(),Crop(1:250, 1:150))
@testset "$(str_showcompact(ops))" begin
    wv = @inferred Augmentor._augment(camera, op)
    @test typeof(wv) <: SubArray
    @test typeof(parent(wv)) <: Base.PermutedDimsArrays.PermutedDimsArray
    @test_reference "rot_crop_rot_crop" wv
    img = @inferred augment(camera, op)
    @test img == parent(copy(wv))
    @test typeof(img) <: Array
    @test eltype(img) <: eltype(camera)
    @test_reference "rot_crop_rot_crop" img
end

# just for code coverage
@test typeof(@inferred(Augmentor.build_pipeline(Rotate90()))) <: Expr
