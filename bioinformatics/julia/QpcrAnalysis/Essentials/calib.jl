# calibration: deconvolution and adjust well-to-well variation in absolute fluorescence values


# scaling factors
const SCALING_FACTORS_deconv = OrderedDict(1=>1.0, 2=>4.2) # used: OrderedDict(1 => 1, 2 => oneof(1, 2, 3.5, 8, 7, 5.6, 4.2))
const SCALING_FACTOR_adj_w2wvaf = 3.7 # used: 9e5, 1e5, 1.2e6, 3




# function: deconvolution and adjust well-to-well variation in absolute fluorescence

function dcv_aw(
    fr_ary3::AbstractArray,
    dcv::Bool,
    channels::AbstractVector,
    # arguments needed if `k_compute=true`
    db_conn::MySQL.MySQLHandle, # `db_conn_default` is defined in "__init__.jl"
    calib_info::Union{Integer,OrderedDict},
    well_nums_found_in_fr::AbstractVector,
    well_nums_in_req=[]::AbstractVector,
    dye_in::AbstractString="FAM",
    dyes_2bfild::AbstractVector=[];
    aw_out_format::AbstractString="both" # "array", "dict", "both"
    )

    calib_info = ensure_ci(db_conn, calib_info)

    wva_data, wva_well_nums = prep_adj_w2wvaf(db_conn, calib_info, well_nums_in_req, dye_in, dyes_2bfild)

    num_channels = length(channels)

    if length(well_nums_found_in_fr) == 0
        well_nums_found_in_fr = wva_well_nums
    end

    wva_well_idc_wfluo = find(wva_well_nums) do wva_well_num
        wva_well_num in well_nums_found_in_fr
    end # do wva_well_num


    mw_ary3 = cat(3, map(1:num_channels) do channel_i # mw = minus water
        fr_ary3[:,:,channel_i] .- transpose(
            wva_data["water"][channels[channel_i]][wva_well_idc_wfluo]
        )
    end...)

    if dcv
        # k_inv_vec = fill(reshape(DataArray([1, 0, 1, 0]), 2, 2), 16) # addition with flexible ratio instead of deconvolution
        k_dict, dcvd_ary3 = deconv(1. * mw_ary3, channels, wva_well_idc_wfluo, db_conn, calib_info, well_nums_in_req; out_format="array")
    else
        k_dict = OrderedDict()
        dcvd_ary3 = mw_ary3
    end

    dcvd_aw_vec = map(1:num_channels) do channel_i
        adj_w2wvaf(
            dcvd_ary3[:,:,channel_i],
            wva_data, wva_well_idc_wfluo,
            channels[channel_i];
            minus_water=false
        )
    end

    dcvd_aw_ary3 = Array{typeof(0.)}(cat(3, dcvd_aw_vec...))
    dcvd_aw_dict = OrderedDict(map(1:num_channels) do channel_i
        channels[channel_i] => dcvd_aw_vec[channel_i]
    end) # do channel_i

    if aw_out_format == "array"
        dcvd_aw = (dcvd_aw_ary3,)
    elseif aw_out_format == "dict"
        dcvd_aw = (dcvd_aw_dict,)
    elseif out_format == "both"
        dcvd_aw = (dcvd_aw_ary3, dcvd_aw_dict)
    else
        error("`out_format` must be \"array\", \"dict\" or \"both\". ")
    end

    return (mw_ary3, k_dict, dcvd_ary3, wva_data, wva_well_nums, dcvd_aw...)

end # dcv_aw


# get all the data from a calibration experiment, including data from all the channels for all the steps
function get_full_calib_data(
    db_conn::MySQL.MySQLHandle,
    calib_info::OrderedDict,
    well_nums::AbstractVector=[]
    )

    calib_info = ensure_ci(db_conn, calib_info)

    calib_key_vec = get_ordered_keys(calib_info)
    cd_key_vec = calib_key_vec[2:end] # cd = channel of dye. "water" is index 1 per original order.
    channels = map(cd_key_vec) do cd_key
        parse(Int, split(cd_key, "_")[2])
    end
    num_channels = length(channels)

    calib_dict = OrderedDict(map(calib_key_vec) do calib_key
        exp_id = calib_info[calib_key]["calibration_id"]
        step_id = calib_info[calib_key]["step_id"]
        k_qry_2b = "
            SELECT fluorescence_value, well_num, channel
                FROM fluorescence_data
                WHERE
                    experiment_id = $exp_id AND
                    step_id = $step_id AND
                    cycle_num = 1
                    well_constraint
                ORDER BY well_num, channel
        "
        calib_data_1key, calib_well_nums = get_mysql_data_well(
            well_nums, k_qry_2b, db_conn, false
        )
        if length(well_nums) > 0 && calib_well_nums != well_nums
            error("Experiment $exp_id, step $step_id: calibration data is not found for all the wells requested. ")
        end # if
        calib_data_1key_chwl = vcat(map(channels) do channel
            transpose(calib_data_1key[calib_data_1key[:channel] .== channel, :fluorescence_value])
        end...) # do channel. return an array where rows indexed by channels and columns indexed by wells

        return calib_key => (calib_data_1key_chwl, calib_well_nums)
    end)

    return calib_dict # share the same keys as `calib_info`

end # get_full_calib_data


# perform deconvolution and adjustment of well-to-well variation on calibration experiment 1 using the k matrix `wva_data` made from calibration expeirment 2
function calib_calib(
    db_conn_1::MySQL.MySQLHandle,
    db_conn_2::MySQL.MySQLHandle,
    calib_info_1::OrderedDict,
    calib_info_2::OrderedDict,
    well_nums_1::AbstractVector=[],
    well_nums_2::AbstractVector=[];
    dye_in::AbstractString="FAM", dyes_2bfild::AbstractVector=[]
    )

    # This function is expected to handle situations where `calib_info_1` and `calib_info_2` have different combinations of wells, but the number of wells should be the same.
    if length(well_nums_1) != length(well_nums_2)
        error("length(well_nums_1) != length(well_nums_2). ")
    end

    calib_dict_1 = get_full_calib_data(db_conn_1, calib_info_1, well_nums_1)
    water_well_nums_1 = calib_dict_1["water"][2]

    calib_key_vec_1 = get_ordered_keys(calib_info_1)
    cd_key_vec_1 = calib_key_vec_1[2:end] # cd = channel of dye. "water" is index 1 per original order.
    channels_1 = map(cd_key_vec_1) do cd_key
        parse(Int, split(cd_key, "_")[2])
    end

    ary2dcv_1 = cat(1, map(values(calib_dict_1)) do value_1
        fluo_data = value_1[1]
        num_channels, num_wells = size(fluo_data)
        reshape(transpose(fluo_data), 1, num_wells, num_channels)
    end...) # do value_1

    mw_ary3_1, k_dict_2, dcvd_ary3_1, wva_data_2, wva_well_nums_2, dcv_aw_ary3_1 = dcv_aw(
        ary2dcv_1, true, channels_1,
        db_conn_2, calib_info_2, well_nums_2, well_nums_2, dye_in, dyes_2bfild;
        aw_out_format="array"
    )

    return OrderedDict(
        "ary2dcv_1"=>ary2dcv_1,
        "mw_ary3_1"=>mw_ary3_1,
        "k_dict_2"=>k_dict_2,
        "dcvd_ary3_1"=>dcvd_ary3_1,
        "wva_data_2"=>wva_data_2,
        "dcv_aw_ary3_1"=>dcv_aw_ary3_1
    )

end # calib_calib



#
