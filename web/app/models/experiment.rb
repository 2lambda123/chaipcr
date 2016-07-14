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
class Experiment < ActiveRecord::Base
  belongs_to :experiment_definition
  
  has_many :fluorescence_data
  has_many :temperature_logs, -> {order("elapsed_time")} do
    def with_range(starttime, endtime, resolution)
      results = where("elapsed_time >= ?", starttime)
      if !endtime.blank?
        results = results.where("elapsed_time <= ?", endtime)
      end
      outputs = []
      counter = 0
      gap = (resolution.blank?)? 1 : resolution.to_i/1000
      results.each do |row|
        if counter == 0
          outputs << row
        end
        counter += 1
        if counter == gap
          counter = 0
        end
      end
      outputs
    end
  end
  
#  validates :time_valid, inclusion: {in: [true, false]}
  
  before_create do |experiment|
#    experiment.time_valid = Setting.time_valid
  end
  
  before_destroy do |experiment|
    if experiment.running?
      errors.add(:base, "cannot delete experiment in the middle of running")
      return false;
    end
  end
  
  after_destroy do |experiment|
    if experiment_definition.experiment_type ==  ExperimentDefinition::TYPE_USER_DEFINED
      experiment_definition.destroy
    end
    
    TemperatureLog.delete_all(:experiment_id => experiment.id)
    TemperatureDebugLog.delete_all(:experiment_id => experiment.id)
    FluorescenceDatum.delete_all(:experiment_id => experiment.id)
    MeltCurveDatum.delete_all(:experiment_id => experiment.id)
    AmplificationCurve.delete_all(:experiment_id => experiment.id)
    AmplificationDatum.delete_all(:experiment_id => experiment.id)
    CachedMeltCurveDatum.delete_all(:experiment_id => experiment.id)
  end
  
  def protocol
    experiment_definition.protocol
  end
  
  def editable?
    return started_at.nil? && experiment_definition.editable?
  end

  def ran?
    return !started_at.nil?
  end
  
  def running?
    return !started_at.nil? && completed_at.nil?
  end
  
  def diagnostic?
    experiment_definition.experiment_type == ExperimentDefinition::TYPE_DIAGNOSTIC
  end
  
  def diagnostic_passed?
    diagnostic? && completion_status == "success" && analyze_status == "success"
  end
  
  def name
    experiment_definition.name
  end

  def calibration_id
    if experiment_definition.guid == "thermal_consistency"
      return 1
    elsif experiment_definition.guid == "optical_cal" || experiment_definition.guid == "dual_channel_optical_cal" ||
          experiment_definition.guid == "optical_test_dual_channel"
      return self.id 
    else
      return read_attribute(:calibration_id)
    end
  end
  
end