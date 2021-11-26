"""
    metropolis!(spins, β, h = 0; steps = 1, save_interval = length(spins))

Perfoms one or more Metropolis MC steps from the configuration `spins`, at inverse
temperature `β`.
Returns three lists: `spins_t, M, E`, where `spins_t` contains configurations
sampled at intervals `save_interval` (by default equals the number of sites),
`M` is the record of magnetizations, and `E` the record of energies.
"""
function metropolis!(
    spins::AbstractMatrix{Int8},
    β::Real,
    h::Real = false;
    steps::Int = 1,
    save_interval::Int = length(spins),
)
    @assert steps ≥ 1
    @assert save_interval ≥ 1

    #= We only need to evalute specific values of acceptance probabilities.
    Therefore we store them in a look-up table. =#
    Paccept = metropolis_acceptance_probabilities(β, h)

    #= Track history of magnetization and energy =#
    M = zeros(Int, steps)
    E = zeros(Int, steps)

    M[1] = sum(spins) # magnetization
    E[1] = energy(spins, h)

    #= Track the history of configurations only every 'save_interval' steps. =#
    spins_t = zeros(Int8, size(spins)..., length(1:save_interval:steps))
    spins_t[:,:,1] .= spins

    for t ∈ 2:steps
        metropolis_step!(spins, h; t = t, M = M, E = E, Paccept = Paccept)
        if t ∈ 1:save_interval:steps
            spins_t[:, :, cld(t, save_interval)] .= spins
        end
    end

    return spins_t, M, E
end

function metropolis_step!(spins::AbstractMatrix, h::Real = false; t, M, E, Paccept)
    i, j = rand.(Base.OneTo.(size(spins)))
    S = neighbor_sum_div_2(spins, i, j)
    ΔE = 2 * (2S + h) * spins[i,j]
    if ΔE ≤ 0 || rand() < Paccept[S + 3]
        M[t] = M[t - 1] - 2spins[i,j]
        E[t] = E[t - 1] + ΔE
        spins[i,j] = -spins[i,j]
        return true
    else
        M[t] = M[t - 1]
        E[t] = E[t - 1]
        return false
    end
end

"""
    metropolis_acceptance_probabilities(β, h = 0)

Returns a tuple of acceptance probabilities, `Paccept`, such that if the sum of
neighboring spins is `S`, then `Paccept[(S + 4) ÷ 2 + 1] == exp(-β * ΔE)`, where
`ΔE = 2 * s[i] * (S + h) > 0` is the energy cost of flipping spin `i` from its
current value `s[i]` to `-s[i]`.
We assume that ΔE > 0, since this is the only case in which this function is called
in the Metropolis algorithm.
Note that `S` can only take the values -4, -2, 0, 2, 4, and therefore
`(S + 4) ÷ 2 + 1 ∈ (1, 2, 3, 4, 5)`.
"""
function metropolis_acceptance_probabilities(β::Real, h::Real = false)
    S = (-4, -2, 0, 2, 4)
    ΔE = 2 .* (S .+ h)
    return exp.(-β .* ΔE)
end
