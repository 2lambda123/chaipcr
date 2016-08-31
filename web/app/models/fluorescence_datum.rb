#
# Chai PCR - Software platform for Open qPCR and Chai's Real-Time PCR instruments.
# For more information visit http://www.chaibio.com
#
# Copyright 2016 Chai Biotechnologies Inc. <info@chaibio.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
class FluorescenceDatum < ActiveRecord::Base
  belongs_to :experiment
  
  scope :for_experiment, lambda {|experiment_id| where(["fluorescence_data.experiment_id=?", experiment_id]).order("fluorescence_data.channel, fluorescence_data.well_num, fluorescence_data.cycle_num")}
  scope :for_stage, lambda {|stage_id| joins("LEFT JOIN ramps ON fluorescence_data.ramp_id = ramps.id INNER JOIN steps ON fluorescence_data.step_id = steps.id OR steps.id = ramps.next_step_id")
                                       .where(["steps.stage_id=?", stage_id])
                                       .order("steps.order_number")}
  
  def self.new_data_generated?(experiment_id, stage_id)
    data = self.for_stage(stage_id).for_experiment(experiment_id).joins("LEFT JOIN amplification_data ON amplification_data.stage_id = steps.stage_id AND amplification_data.experiment_id = fluorescence_data.experiment_id AND amplification_data.well_num = fluorescence_data.well_num+1 AND amplification_data.cycle_num = fluorescence_data.cycle_num")
            .reorder("fluorescence_data.cycle_num DESC").select("fluorescence_data.*, background_subtracted_value").first
    return data != nil && data.background_subtracted_value == nil 
  end
  
  def self.last_cycle(experiment_id, stage_id)
    cycle_num = self.for_stage(stage_id).for_experiment(experiment_id).maximum(:cycle_num)
    (cycle_num.nil?)? 0 : cycle_num
  end
  
end
