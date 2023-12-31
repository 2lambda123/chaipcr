###
Chai PCR - Software platform for Open qPCR and Chai's Real-Time PCR instruments.
For more information visit http://www.chaibio.com

Copyright 2016 Chai Biotechnologies Inc. <info@chaibio.com>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
###
window.ChaiBioTech.ngApp.service 'AmplificationChartHelper', [
  'SecondsDisplay'
  '$filter'
  'Experiment'
  (SecondsDisplay, $filter, Experiment) ->

    @chartConfig = ->
      axes:
        x:
          min: 1
          key: 'cycle_num'
          ticks: 8
          label: 'Cycles'
        y:
          unit: 'k'
          label: 'Relative Fluorescence'
          ticks: 10
          tickFormat: (y) ->
            # if y >= 1000 then Math.round(( y / 1000) * 10) / 10 else Math.round(y * 10) / 10
            Math.round(( y / 1000) * 10) / 10

      box:
        label:
          x: 'Cycle'
          y: 'RFU'

      series: []

    # end chartConfig

    @COLORS = [
        '#33CCFF'
        '#66CC33'
        '#990099'
        '#FF0033'
        '#0033CC'
        '#FF6600'
        '#FF66CC'
        '#FFCC00'
        '#33CCFF'
        '#66CC33'
        '#990099'
        '#FF0033'
        '#0033CC'
        '#FF6600'
        '#FF66CC'
        '#FFCC00'
      ]

    @SAMPLE_TARGET_COLORS = [
        '#33CCFF'
        '#66CC33'
        '#990099'
        '#FF0033'
        '#0033CC'
        '#FF6600'
        '#FF66CC'
        '#FFCC00'
        '#33CCFF'
        '#66CC33'
        '#990099'
        '#FF0033'
        '#0033CC'
        '#FF6600'
        '#FF66CC'
        '#FFCC00'
      ]

    mathPow = (dec, pow) ->
      res = 1
      i = 0
      if pow == 0 then return 1
      else if pow < 0
        for i in [0...Math.abs(pow)]
          res = res / dec
        return res;
      else 
        for i in [0...Math.abs(pow)]
          res = res * dec;
        return res;

    @neutralizeData = (amplification_data, targets, is_dual_channel=false) ->
      amplification_data = angular.copy amplification_data
      targets = angular.copy targets

      channel_datasets = {}
      channels_count = if is_dual_channel then 2 else 1

      # get max cycle
      max_cycle = 0
      for datum in amplification_data by 1
        max_cycle = if datum[2] > max_cycle then datum[2] else max_cycle

      for channel_i in [1..channels_count] by 1
        dataset_name = "channel_#{channel_i}"
        channel_datasets[dataset_name] = []
        channel_data = _.filter amplification_data, (datum) ->
          target = _.filter targets, (target) ->
            target && target.id is datum[0]          
          target.length && target[0].channel is channel_i

        for cycle_i in [1..max_cycle] by 1          
          data_by_cycle = _.filter channel_data, (datum) ->
            datum[2] is cycle_i
          data_by_cycle = _.sortBy data_by_cycle, (d) ->
            d[1]
          channel_datasets[dataset_name].push data_by_cycle

        console.log('channel_datasets[dataset_name]')
        # console.log(channel_datasets[dataset_name])
        
        channel_datasets[dataset_name] = _.map channel_datasets[dataset_name], (datum) ->
          if datum[0]
            pt = cycle_num: datum[0][2]
            for y_item, i in datum by 1
              pt["well_#{y_item[1]-1}_background"] = y_item[3]
              pt["well_#{y_item[1]-1}_baseline"] =  y_item[4]
              pt["well_#{y_item[1]-1}_background_log"] = if y_item[3] > 0 then y_item[3] else 10
              pt["well_#{y_item[1]-1}_baseline_log"] =  if y_item[4] > 0 then y_item[4] else 10

              pt["well_#{y_item[1]-1}_dr1_pred"] = y_item[5]
              pt["well_#{y_item[1]-1}_dr2_pred"] = y_item[6]
            return pt
          else
            {}
      return channel_datasets

    @normalizeWellTargetData = (well_data, init_targets, is_dual_channel) ->
      well_data = angular.copy well_data
      targets = angular.copy init_targets
      channel_count = if is_dual_channel then 2 else 1

      for i in [0.. targets.length - 1] by 1
        targets[i] = 
          id: null
          name: null
          channel: null
          color: null

      for i in [0.. well_data.length - 1] by 1
        targets[(well_data[i].well_num - 1) * channel_count + well_data[i].channel - 1] = 
          id: well_data[i].target_id
          name: well_data[i].target_name
          channel: well_data[i].channel
          color: well_data[i].color        

      return targets

    @blankWellTargetData = (well_data) ->
      well_data = angular.copy well_data
      targets = []

      for i in [0.. well_data.length - 1] by 1
        targets.push 
          id: well_data[i].target_id
          name: well_data[i].target_name
          channel: well_data[i].channel
          color: well_data[i].color

      return targets

    @normalizeTargetData = (target_data, well_targets) ->
      target_data = angular.copy target_data
      well_targets = angular.copy well_targets
      targets = []

      for i in [1.. target_data.length - 1] by 1
        targets.push 
          id: target_data[i][0]
          name: target_data[i][1]

      return targets

    @initialSummaryData = (summary_data, target_data) ->
      summary_data = angular.copy summary_data
      target_data = angular.copy target_data
      summary_data[0].push "channel"
      for i in [1.. summary_data.length - 1] by 1
        target = _.filter target_data, (elem) ->
          elem[0] is summary_data[i][0]

        summary_data[i].push target[0][2]
      return _.sortBy summary_data, (elem) ->
        elem[elem.length - 1]

    @normalizeSummaryData = (summary_data, target_data, well_targets) ->
      summary_data = angular.copy summary_data
      target_data = angular.copy target_data
      well_targets = angular.copy well_targets

      well_data = []

      for i in [1.. summary_data.length - 1] by 1
        item = {}
        for item_name in [0..summary_data[0].length - 1] by 1
          item[summary_data[0][item_name]] = summary_data[i][item_name]

        target = _.filter well_targets, (target) ->
          target and target.id is item.target_id and target.well_num is item.well_num

        if target.length
          item['target_name'] = target[0].name if target[0]
          item['channel'] = target[0].channel if target[0]
          item['color'] = target[0].color if target[0]
          item['well_type'] = target[0].well_type if target[0]
        else
          target = _.filter target_data, (target) ->
            target[0] is item.target_id
          item['target_name'] = target[0][1] if target[0]
          item['channel'] = target[0][2]
          item['color'] = @SAMPLE_TARGET_COLORS[target[0][2] - 1]
          item['well_type'] = ''

        item['active'] = false

        item['mean_quantity'] = item['mean_quantity_m'] * mathPow(10, item['mean_quantity_b'])
        item['quantity'] = item['quantity_m'] * mathPow(10, item['quantity_b'])

        well_data.push item

      well_data = _.orderBy(well_data,['well_num', 'channel'],['asc', 'asc']);      

      return well_data

    @normalizeSimpleSummaryData = (well_data, targetsSet) ->
      well_data = angular.copy well_data
      targetsSet = angular.copy targetsSet

      simple_well_data = []

      for i in [0.. 15] by 1
        item = {}
        targets = []
        well_line_items = _.filter well_data, (line_item) ->
          line_item.well_num == i+1

        if well_line_items.length
          for j in [0.. targetsSet.length - 1] by 1
            target_item = {}
            well_item = _.filter well_line_items, (line_item) ->
              line_item.target_id == targetsSet[j].id

            target_item['target_id'] = targetsSet[j].id
            target_item['color'] = targetsSet[j].color
            target_item['channel'] = targetsSet[j].channel
            if well_item.length
              target_item['cq'] = well_item[0].cq 
              target_item['assigned'] = true
            else 
              target_item['cq'] = 0
              target_item['assigned'] = false

            targets.push target_item

          item['well_num'] = well_line_items[0].well_num
          item['color'] = well_line_items[0].color
          item['active'] = false
          item['targets'] = targets

          simple_well_data.push item

      simple_well_data = _.orderBy(simple_well_data,['well_num'],['asc']);      

      return simple_well_data


    @blankWellData = (is_dual_channel, well_targets) ->
      well_targets = angular.copy well_targets
      well_data = []
      for i in [0.. 15] by 1
        item = {}
        item['well_num'] = i+1
        item['replic_group'] = null
        item['quantity_m'] = null
        item['quantity_b'] = null
        item['quantity'] = 0
        item['mean_quantity_m'] = null
        item['mean_quantity_b'] = null
        item['mean_quantity'] = 0
        item['mean_cq'] = null
        item['cq'] = null
        item['channel'] = 1
        item['active'] = false

        if is_dual_channel
          item['target_name'] = well_targets[2*i].name if well_targets[2*i]
          item['target_id'] = well_targets[2*i].id if well_targets[2*i]
          item['color'] = well_targets[2*i].color if well_targets[2*i]
          item['well_type'] = well_targets[2*i].well_type if well_targets[2*i]
        else
          item['target_name'] = well_targets[i].name if well_targets[i]
          item['target_id'] = well_targets[i].id if well_targets[i]
          item['color'] = well_targets[i].color if well_targets[i]
          item['well_type'] = well_targets[i].well_type if well_targets[i]

        well_data.push item

        if is_dual_channel
          dual_item = angular.copy item
          dual_item['target_name'] = well_targets[2*i+1].name if well_targets[2*i+1]
          dual_item['target_id'] = well_targets[2*i+1].id if well_targets[2*i+1]
          dual_item['color'] = well_targets[2*i+1].color if well_targets[2*i+1]
          dual_item['well_type'] = well_targets[2*i+1].well_type if well_targets[2*i+1]
          dual_item['channel'] = 2
          well_data.push dual_item

      return well_data

    @paddData = (cycle_num = 1) ->
      paddData = cycle_num: cycle_num
      for i in [0..15] by 1
        paddData["well_#{i}_baseline"] = 0
        paddData["well_#{i}_background"] = 0
        paddData["well_#{i}_background_log"] = 0
        paddData["well_#{i}_baseline_log"] = 0
        paddData["well_#{i}_dr1_pred"] = 0
        paddData["well_#{i}_dr2_pred"] = 0
  
      channel_1: [paddData]
      channel_2: [paddData]

    @getMaxExperimentCycle = Experiment.getMaxExperimentCycle

    return
]
