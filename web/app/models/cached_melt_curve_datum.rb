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
class CachedMeltCurveDatum < ActiveRecord::Base
  belongs_to :experiment
  
  ["temperature", "fluorescence_data", "derivative", "tm", "area"].each do |variable|
    define_method("#{variable}") do
      value = instance_variable_get("@#{variable}")
      if value.nil?
        value = read_attribute("#{variable}_text".to_sym)
        value = value.split(",").map {|v| v.to_f}
        instance_variable_set("@#{variable}", value)
      end
      return value
    end
    
    define_method("#{variable}=") do |value|
      instance_variable_set("@#{variable}", value)
      write_attribute("#{variable}_text".to_sym, (value)? value.join(",") : "")
    end  
  end
  
  def self.retrieve(experiment_id, stage_id)
    self.where(:experiment_id=>experiment_id, :stage_id=>stage_id).order(:channel, :well_num)
  end
  
  def self.maxid(experiment_id, stage_id)
    self.where(:experiment_id=>experiment_id, :stage_id=>stage_id).maximum(:id)
  end

end
