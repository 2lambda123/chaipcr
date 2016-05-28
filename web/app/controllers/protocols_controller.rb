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
class ProtocolsController < ApplicationController
  include ParamsHelper
  before_filter :ensure_authenticated_user, :except => :create
  before_filter :experiment_definition_editable_check
    
  respond_to :json
  
  resource_description { 
    formats ['json']
  }
  
  def_param_group :protocol do
    param :protocol, Hash, :desc => "Protocol Info", :required => true do
      param :lid_temperature, Float, :desc => "lid temperature, in degree C, default is 110, with precision to one decimal point", :required => true
    end
  end
  
  api :PUT, "/protocols/:id", "Update a protocol"
  param_group :protocol
  def update
    ret  = @protocol.update_attributes(protocol_params)
    respond_to do |format|
      format.json { render "show", :status => (ret)? :ok : :unprocessable_entity}
    end
  end
  
  protected
  
  def get_experiment
    @protocol = Protocol.find_by_id(params[:id])
    @experiment = Experiment.where("experiment_definition_id=?", @protocol.experiment_definition_id).first if !@protocol.nil?
  end
  
end