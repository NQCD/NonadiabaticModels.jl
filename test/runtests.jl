using Test
using NonadiabaticDynamicsBase
using NonadiabaticModels
using LinearAlgebra
using FiniteDiff

function finite_difference_gradient(model::AdiabaticModel, R)
    f(x) = potential(model, x)
    FiniteDiff.finite_difference_gradient(f, R)
end

function finite_difference_gradient(model::DiabaticModel, R)
    f(x, i, j) = potential(model, x)[i,j]
    grad = [Hermitian(zeros(model.n_states, model.n_states)) for i in CartesianIndices(R)]
    for k in eachindex(R)
        for i=1:model.n_states
            for j=1:model.n_states
                grad[k].data[i,j] = FiniteDiff.finite_difference_gradient(x->f(x,i,j), R)[k]
            end
        end
    end
    grad
end

function test_model(model::Model, DoFs, atoms; rtol=1e-5)
    R = rand(DoFs, atoms)
    D = derivative(model, R)
    finite_diff = finite_difference_gradient(model, R)
    return isapprox(finite_diff, D, rtol=rtol)
end

function test_model(model::AdiabaticFrictionModel, DoFs, atoms)
    R = rand(DoFs, atoms)
    D = derivative(model, R)
    friction(model, R)
    return finite_difference_gradient(model, R) ≈ D
end

@testset "DiatomicHarmonic" begin
    model = DiatomicHarmonic()
    @test test_model(model, 3, 2)

    R = [0 0; 0 0; 1 0]
    @test potential(model, R) ≈ 0
    R = [sqrt(3) 0; sqrt(3) 0; sqrt(3) 0]
    @test potential(model, R) ≈ 2
end

@testset "AdiabaticModels" begin
    @test test_model(Harmonic(), 3, 10)
    @test test_model(Free(), 3, 10)
    @test test_model(DebyeBosonBath(10), 1, 10)
    @test test_model(DarlingHollowayElbow(), 1, 2)
end

@testset "DiabaticModels" begin
    @test test_model(DoubleWell(), 1, 1)
    @test test_model(TullyModelOne(), 1, 1)
    @test test_model(TullyModelTwo(), 1, 1)
    @test test_model(TullyModelThree(), 1, 1)
    @test test_model(Scattering1D(), 1, 1)
    @test test_model(ThreeStateMorse(), 1, 1)
    @test test_model(DebyeSpinBoson(10), 1, 10)
    @test test_model(OuyangModelOne(), 1, 1)
    @test test_model(GatesHollowayElbow(), 1, 2)
    # test_model(Subotnik_A(), 1, 1) broken
    @test test_model(MiaoSubotnik(), 1, 1)
end

@testset "FrictionModels" begin
    @test test_model(ConstantFriction(Free(), 1), 1, 3)
    @test test_model(RandomFriction(Free()), 1, 3)
end

@testset "JuLIP" begin
    import JuLIP
    atoms = Atoms([:H, :H])
    vecs = [10 0 0; 0 10 0; 0 0 10]
    model = JuLIPModel(atoms, PeriodicCell(vecs), JuLIP.StillingerWeber())
    @test_broken test_model(model, 3, 2)
end

@testset "ASE" begin
    using PyCall

    ase = pyimport("ase")

    h2 = ase.Atoms("H2", [(0, 0, 0), (0, 0, 0.74)])
    h2.center(vacuum=2.5)

    @testset "EMT" begin
        emt = pyimport("ase.calculators.emt")
        h2.calc = emt.EMT()
        model = AdiabaticASEModel(h2)
        @test test_model(model, 3, 2)
    end

    @testset "GPAW" begin
        gpaw = pyimport("gpaw")
        h2.calc = gpaw.GPAW(xc="PBE", mode=gpaw.PW(300), txt="h2.txt")
        model = AdiabaticASEModel(h2)
        @test test_model(model, 3, 2, rtol=1e-3)
    end

end
