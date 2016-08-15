type FREAK <: DescriptorParams
    pattern_scale::Float64
    octaves::Int
end

typealias SamplePair Vector{Float64}

function FREAK(; pattern_scale::Float64 = 22.0, octaves::Int = 4)
    FREAK(pattern_scale, octaves)
end

function _freak_orientation{T<:Gray}(img::AbstractArray{T, 2}, int_img::AbstractArray{T, 2}, keypoint::Keypoint, pattern::Array{SamplePair})
    direction_sum_y = 0.0
    direction_sum_x = 0.0
    for o in freak_orientation_sampling_pattern
        offset_1 = round(Int, pattern[o[1]])
        offset_2 = round(Int, pattern[o[2]])
        point_1 = keypoint + CartesianIndex(offset_1[1], offset_1[2])
        point_2 = keypoint + CartesianIndex(offset_2[1], offset_2[2])
        intensity_diff = img[point_1] - img[point_2]
        dy, dx = offset_1 - offset_2
        norm = (dx ^ 2 + dy ^ 2) ^ 0.5
        direction_sum_y += dy * intensity_diff / norm
        direction_sum_x += dx * intensity_diff / norm
    end
    atan2(direction_sum_y, direction_sum_x)
end

function _freak_mean_intensity{T<:Gray}(int_img::AbstractArray{T, 2}, )
end

function _freak_tables(pattern_scale::Float64, scale_step::Float64)
    pattern_table = Array{SamplePair}[]
    smoothing_table = Array{Float64}[]
    window_sizes = Int[]
    for i in 0:freak_num_scales-1
        scale_factor = scale_step ^ i
        pattern = SamplePair[]
        sigmas = Float64[]
        largest_window = 0
        for (i, n) in enumerate(freak_num_circular_pattern)
            for circle_number in 0:n - 1
                alt_offset = (pi / n) * ((i - 1) % 2)
                angle = (circle_number * 2 * pi / n) + alt_offset

                push!(pattern, SamplePair([freak_radii[i] * sin(angle) * scale_factor * pattern_scale, 
                                            freak_radii[i] * cos(angle) * scale_factor * pattern_scale]))
                push!(sigmas, freak_sigma[i] * scale_factor * pattern_scale)

                largest_window = max(ceil(Int, (freak_radii[i] + freak_sigma[i]) * scale_factor * pattern_scale) + 1, largest_window)
            end
        end
        push!(pattern_table, pattern)
        push!(smoothing_table, sigmas)
        push!(window_sizes, largest_window)
    end
    pattern_table, smoothing_table, window_sizes
end

function create_descriptor{T<:Gray}(img::AbstractArray{T, 2}, keypoints::Keypoints, params::FREAK)
    scale_step = 2 ^ (params.octaves / freak_num_scales)
    pattern_table, smoothing_table, window_sizes = _freak_tables(params.pattern_scale, scale_step)
    int_img = integral_image(img)
    descriptors = BitArray[]
    for k in keypoints
        orientation = _freak_orientation(img, int_img, k, pattern_table[TEMP])
        sin_angle = sin(orientation)
        cos_angle = cos(orientation)
        sampled_intensities = T[]
        
        descriptor = falses(512)
        for (i, f) in enumerate(freak_sampling_pattern)
            point_1 = sampled_intensities[f[1]]
            point_2 = sampled_intensities[f[2]]
            descriptor[i] = point_1 < point_2
        end
        push!(descriptors, descriptor)
    end
    descriptors
end