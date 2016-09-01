
#constants
const deltaTSetPoint = 1
const highTemperature = 95
const lowTemperature = 50
# xqrm
const HIGH_TEMP_mDELTA = highTemperature - deltaTSetPoint
const LOW_TEMP_pDELTA = lowTemperature + deltaTSetPoint
const MIN_AVG_RAMP_RATE = 2 # C/s
const MAX_TOTAL_TIME = 22.5e3 # ms
const MAX_BLOCK_DELTA = 2 # C
const MIN_HEATING_RATE = 1 # C/s
const MAX_TIME_TO_HEAT = 90e3 # ms


ANALYZE_DICT["thermal_performance_diagnostic"] = function analyze_thermal_performance_diagnostic(
    db_conn::MySQL.MySQLHandle,
    exp_id::Integer, # really used
    calib_info::Union{Integer,OrderedDict} # not used for computation
    )

    #extract data from database
    queryTemperatureData = "SELECT * FROM temperature_logs WHERE experiment_id = $exp_id order by elapsed_time"
    temperatureData = mysql_execute(db_conn, queryTemperatureData)
    num_dp = size(temperatureData)[1] # dp = data points

    #add a new column (not row) that is the average of the two heat block zones
    hbzt_avg = map(1:num_dp) do i
        mean(Array(temperatureData[i, [:heat_block_zone_1_temp, :heat_block_zone_2_temp]]))
    end # do i

    elapsed_times = temperatureData[:elapsed_time]

    #calculate average ramp rates up and down of the heat block

    #first, calculate the time the heat block reaches the high temperature/also the time the ramp up ends and the ramp down starts
    elapsed_times_high_temp = elapsed_times[find(hbzt_avg) do temp
        temp > HIGH_TEMP_mDELTA
    end] # do temp
    apprxRampUpEndTime, apprxRampDownStartTime = extrema(elapsed_times_high_temp)

    #second, calculate the time the ramp up starts and the ramp down ends
    elapsed_times_low_temp = elapsed_times[find(hbzt_avg) do temp
        temp < LOW_TEMP_pDELTA
    end] # do temp
    apprxRampDownEndTime, apprxRampUpStartTime = extrema(elapsed_times_low_temp)

    apprxRampDownEndTime = try
        minimum(elapsed_times[find(1:num_dp) do i
            hbzt_avg[i] < LOW_TEMP_pDELTA && elapsed_times[i] > apprxRampDownStartTime
        end]) # do temp
    catch
        Inf
    end # try minimum
    apprxRampUpStartTime = try
        maximum(elapsed_times[find(1:num_dp) do i
            hbzt_avg[i] < LOW_TEMP_pDELTA && elapsed_times[i] < apprxRampUpEndTime
        end]) # do temp
    catch
        -Inf
    end # try maximum


    temp_range_adj = (HIGH_TEMP_mDELTA - LOW_TEMP_pDELTA) * 1000

    #calculate the average ramp rate up and down in degrees C per second
    Heating_TotalTime = apprxRampUpEndTime - apprxRampUpStartTime
    Heating_AvgRampRate = temp_range_adj / Heating_TotalTime
    Cooling_TotalTime = apprxRampDownEndTime - apprxRampDownStartTime
    Cooling_AvgRampRate = temp_range_adj / Cooling_TotalTime

    #calculate maximum temperature difference between heat block zones during ramp up and down
    Heating_MaxBlockDeltaT, Cooling_MaxBlockDeltaT = map((
        [apprxRampUpStartTime, apprxRampUpEndTime],
        [apprxRampDownStartTime, apprxRampDownEndTime]
    )) do time_vec
        elapsed_time_idc = find(elapsed_times) do elapsed_time
            time_vec[1] < elapsed_time < time_vec[2]
        end # do elapsed_time
        maximum(abs(temperatureData[elapsed_time_idc, :heat_block_zone_1_temp] .- temperatureData[elapsed_time_idc, :heat_block_zone_2_temp]))
    end # do time_vec

    #calculate the average ramp rate of the lid heater in degrees C per second
    lidHeaterStartRampTime = minimum(elapsed_times[
        find(temperatureData[:lid_temp]) do lid_temp
            lid_temp > LOW_TEMP_pDELTA
        end
    ])
    lidHeaterStopRampTime = maximum(elapsed_times[
        find(temperatureData[:lid_temp]) do lid_temp
            lid_temp < HIGH_TEMP_mDELTA
        end
    ])
    Lid_TotalTime = lidHeaterStopRampTime - lidHeaterStartRampTime
    Lid_HeatingRate = temp_range_adj / Lid_TotalTime


    results = OrderedDict(
        "Heating" => OrderedDict(
            "AvgRampRate" => (Heating_AvgRampRate, Heating_AvgRampRate >= MIN_AVG_RAMP_RATE),
            "TotalTime" => (Heating_TotalTime, Heating_TotalTime <= MAX_TOTAL_TIME),
            "MaxBlockDeltaT" => (Heating_MaxBlockDeltaT, Heating_MaxBlockDeltaT <= MAX_BLOCK_DELTA)
        ),
        "Cooling" => OrderedDict(
            "AvgRampRate" => (Cooling_AvgRampRate, Cooling_AvgRampRate >= MIN_AVG_RAMP_RATE),
            "TotalTime" => (Cooling_TotalTime, Cooling_TotalTime <= MAX_TOTAL_TIME),
            "MaxBlockDeltaT" => (Cooling_MaxBlockDeltaT, Cooling_MaxBlockDeltaT <= MAX_BLOCK_DELTA)
        ),
        "Lid" => OrderedDict(
            "HeatingRate" => (Lid_HeatingRate, Lid_HeatingRate >= MIN_HEATING_RATE),
            "TotalTime" => (Lid_TotalTime, Lid_TotalTime <= MAX_TIME_TO_HEAT)
        )
    )

    return(json(results))

end # analyze_thermal_performance_diagnostic
