# chaipcr/web/public/dynexp/optical_test_single_channel/analyze.R

# constants
const BASELINE_STEP_ID = 12
const EXCITATION_STEP_ID = 13
const MIN_EXCITATION_FLUORESCENCE = 5120
const MIN_EXCITATION_FLUORESCENCE_MULTIPLE = 3
const MAX_EXCITATION = 384000


ANALYZE_DICT["optical_test_single_channel"] = function analyze_optical_test_single_channel(
    db_conn::MySQL.MySQLHandle,
    exp_id::Integer,
    calib_info::Union{Integer,OrderedDict}=calib_info_AIR; # not used for computation
    # start: arguments that might be passed by upstream code
    well_nums::AbstractVector=[],
    )

    step_ids = [BASELINE_STEP_ID, EXCITATION_STEP_ID]
    ot_dict = OrderedDict(map(step_ids) do step_id
        ot_qry_2b = "SELECT fluorescence_value, well_num
            FROM fluorescence_data
            WHERE
                experiment_id = $exp_id AND
                step_id = $step_id AND
                cycle_num = 1
                well_constraint
            ORDER BY well_num
        "
        ot_df, fluo_well_nums = get_mysql_data_well(
            well_nums, ot_qry_2b, db_conn, false
        )
        step_id => ot_df[:fluorescence_value]
    end) # do step_id

    # assuming the 2 values of `ot_dict` are the same in length (number of wells)
    results = map(1:length(ot_dict[step_ids[1]])) do well_i
        baseline, excitation = map(step_ids) do step_id
            ot_dict[step_id][well_i]
        end # do step_id
        # valid = (excitation >= MIN_EXCITATION_FLUORESCENCE) && (excitation / baseline >= MIN_EXCITATION_FLUORESCENCE_MULTIPLE) && (excitation <= MAX_EXCITATION) # old
        valid = (excitation >= MIN_EXCITATION_FLUORESCENCE) && (baseline < MIN_EXCITATION_FLUORESCENCE) && (excitation <= MAX_EXCITATION) # Josh, 2016-08-15
        OrderedDict("baseline"=>baseline, "excitation"=>excitation, "valid"=>valid)
    end # do well_i

    return json(OrderedDict("optical_data"=>results))

end # analyze_optical_test_single_channel
