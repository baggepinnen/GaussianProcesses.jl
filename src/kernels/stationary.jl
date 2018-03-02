# Subtypes of Stationary must define the following functions:
# cov(k::Stationary, r::Float64) = ::Float64
# grad_kern!

@compat abstract type Stationary{D} <: Kernel where D <: Distances.SemiMetric end
@compat abstract type StationaryData <: KernelData end

function metric(kernel::Stationary{D}) where D <: Distances.SemiMetric
    return D()
end
function metric(kernel::Stationary{WeightedSqEuclidean})
    return WeightedSqEuclidean(ard_weights(kernel))
end
function metric(kernel::Stationary{WeightedEuclidean})
    return WeightedEuclidean(ard_weights(kernel))
end
ard_weights(kernel::Stationary{WeightedSqEuclidean}) = kernel.iℓ2
ard_weights(kernel::Stationary{WeightedEuclidean}) = kernel.iℓ2

cov{V1<:VecF64,V2<:VecF64}(k::Stationary, x::V1, y::V2) = cov(k, distance(k, x, y))

function cov!{M1<:MatF64,M2<:MatF64}(cK::MatF64, k::Stationary, X1::M1, X2::M2)
    dim1, nobsv1 = size(X1)
    dim2, nobsv2 = size(X2)
    dim1==dim2 || throw(ArgumentError("X1 and X2 must have same dimension"))
    nobsv1==size(cK,1) || throw(ArgumentError("X1 and cK incompatible nobsv"))
    nobsv2==size(cK,2) || throw(ArgumentError("X2 and cK incompatible nobsv"))
    dim = dim1
    met = metric(k)
    for i in 1:nobsv1
        for j in 1:nobsv2
            cK[i,j] = cov(k, distij(met, X1, X2, i, j, dim))
        end
    end
    return cK
end
function addcov!{M0<:MatF64,M1<:MatF64,M2<:MatF64}(cK::M0, k::Stationary, X1::M1, X2::M2)
    dim1, nobsv1 = size(X1)
    dim2, nobsv2 = size(X2)
    dim1==dim2 || throw(ArgumentError("X1 and X2 must have same dimension"))
    nobsv1==size(cK,1) || throw(ArgumentError("X1 and cK incompatible nobsv"))
    nobsv2==size(cK,2) || throw(ArgumentError("X2 and cK incompatible nobsv"))
    dim = dim1
    met = metric(k)
    for i in 1:nobsv1
        for j in 1:nobsv2
            cK[i,j] += cov(k, distij(met, X1, X2, i, j, dim))
        end
    end
    return cK
end
function multcov!{M0<:MatF64,M1<:MatF64,M2<:MatF64}(cK::M0, k::Stationary, X1::M1, X2::M2)
    dim1, nobsv1 = size(X1)
    dim2, nobsv2 = size(X2)
    dim1==dim2 || throw(ArgumentError("X1 and X2 must have same dimension"))
    nobsv1==size(cK,1) || throw(ArgumentError("X1 and cK incompatible nobsv"))
    nobsv2==size(cK,2) || throw(ArgumentError("X2 and cK incompatible nobsv"))
    dim = dim1
    met = metric(k)
    for i in 1:nobsv1
        for j in 1:nobsv2
            cK[i,j] *= cov(k, distij(met, X1, X2, i, j, dim))
        end
    end
    return cK
end
function cov(k::Stationary, X1::MatF64, X2::MatF64)
    nobsv1 = size(X1, 2)
    nobsv2 = size(X2, 2)
    cK = Array{Float64}(nobsv1, nobsv2)
    cov!(cK, k, X1, X2)
    return cK
end

function cov!{M<:MatF64}(cK::MatF64, k::Stationary, X::M)
    dim, nobsv = size(X)
    nobsv==size(cK,1) || throw(ArgumentError("X and cK incompatible nobsv"))
    nobsv==size(cK,2) || throw(ArgumentError("X and cK incompatible nobsv"))
    met = metric(k)
    @inbounds for i in 1:nobsv
        for j in 1:i
            cK[i,j] = cov(k, distij(met, X, i, j, dim))
            cK[j,i] = cK[i,j]
        end
    end
    return cK
end
function cov!(cK::MatF64, k::Stationary, X::MatF64, data::StationaryData)
    cov!(cK, k, X)
end
function cov(k::Stationary, X::MatF64, data::StationaryData)
    nobsv = size(X, 2)
    cK = Matrix{Float64}(nobsv, nobsv)
    cov!(cK, k, X, data)
end
function cov{M<:MatF64}(k::Stationary, X::M)
    nobsv = size(X, 2)
    cK = Matrix{Float64}(nobsv, nobsv)
    cov!(cK, k, X)
end
function addcov!{M<:MatF64}(cK::MatF64, k::Stationary, X::M)
    dim, nobsv = size(X)
    nobsv==size(cK,1) || throw(ArgumentError("X and cK incompatible nobsv"))
    nobsv==size(cK,2) || throw(ArgumentError("X and cK incompatible nobsv"))
    met = metric(k)
    @inbounds for i in 1:nobsv
        for j in 1:i
            cK[i,j] += cov(k, distij(met, X, i, j, dim))
            cK[j,i] = cK[i,j]
        end
    end
    return cK
end
function addcov!(cK::MatF64, k::Stationary, X::MatF64, d::StationaryData)
    addcov!(cK, k, X)
end
function multcov!{M<:MatF64}(cK::MatF64, k::Stationary, X::M)
    dim, nobsv = size(X)
    nobsv==size(cK,1) || throw(ArgumentError("X and cK incompatible nobsv"))
    nobsv==size(cK,2) || throw(ArgumentError("X and cK incompatible nobsv"))
    met = metric(k)
    @inbounds for i in 1:nobsv
        for j in 1:i
            cK[i,j] *= cov(k, distij(met, X, i, j, dim))
            cK[j,i] = cK[i,j]
        end
    end
    return cK
end
function multcov!(cK::MatF64, k::Stationary, X::MatF64, data::StationaryData)
    multcov!(cK, k, X)
end
dk_dlσ(k::Stationary, r::Float64) = 2.0*cov(k,r)

# Isotropic Kernels

@compat abstract type Isotropic{D} <: Stationary{D} end

type IsotropicData <: StationaryData
    R::Matrix{Float64}
end

function KernelData{M<:MatF64}(k::Isotropic, X::M)
     IsotropicData(distance(k, X))
end
function kernel_data_key{M<:MatF64}(k::Isotropic, X::M)
    return @sprintf("%s_%s", "IsotropicData", metric(k))
end

function addcov!{M<:MatF64}(cK::MatF64, k::Isotropic, X::M, data::IsotropicData)
    dim, nobsv = size(X)
    met = metric(k)
    for j in 1:nobsv
        @simd for i in 1:j
            @inbounds cK[i,j] += cov(k, distij(met, X, i, j, dim))
            @inbounds cK[j,i] = cK[i,j]
        end
    end
    return cK
end
@inline function dKij_dθp{M<:MatF64}(kern::Isotropic,X::M,i::Int,j::Int,p::Int,dim::Int)
    return dk_dθp(kern, distij(metric(kern),X,i,j,dim),p)
end
@inline function dKij_dθp{M<:MatF64}(kern::Isotropic,X::M,data::IsotropicData,i::Int,j::Int,p::Int,dim::Int)
    return dk_dθp(kern, data.R[i,j],p)
end
function grad_kern{V1<:VecF64,V2<:VecF64}(kern::Isotropic, x::V1, y::V2)
    dist=distance(kern,x,y)
    return [dk_dθp(kern,dist,k) for k in 1:num_params(kern)]
end

# StationaryARD Kernels

@compat abstract type StationaryARD{D} <: Stationary{D} end

type StationaryARDData <: StationaryData
    dist_stack::Array{Float64, 3}
end

# May need to customized in subtypes
function KernelData{M<:MatF64}(k::StationaryARD, X::M)
    dim, nobsv = size(X)
    dist_stack = Array{Float64}( nobsv, nobsv, dim)
    for d in 1:dim
        grad_ls = view(dist_stack, :, :, d)
        pairwise!(grad_ls, SqEuclidean(), view(X, d:d,:))
    end
    StationaryARDData(dist_stack)
end
kernel_data_key{M<:MatF64}(k::StationaryARD, X::M) = @sprintf("%s_%s", "StationaryARDData", metric(k))

