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
require 'zip'
require 'rserve'

class ExperimentsController < ApplicationController
  include ParamsHelper
  
  before_filter :ensure_authenticated_user
  before_filter :get_experiment, :except => [:index, :create, :copy]
  
  respond_to :json

  resource_description { 
    formats ['json']
  }
  
  RSERVE_TIMEOUT  = 240
  
  BackgroundTask = Struct.new(:action, :experiment_id, :complete_result) do
    def completed?
      complete_result != nil
    end
    
    def match?(action, experiment_id)
      return self.action == action && self.experiment_id == experiment_id
    end
  end
  @@background_task = nil
  @@background_last_task = nil
  
  def_param_group :experiment do
    param :experiment, Hash, :desc => "Experiment Info", :required => true do
      param :name, String, :desc => "Name of the experiment", :required => false
      param :guid, String, :desc => "GUID used for diagnostic or calibration", :required => false
    end
  end
  
  api :GET, "/experiments", "List all the experiments"
  example "[{'experiment':{'id':1,'name':'test1','type':'user','started_at':null,'completed_at':null,'completed_status':null}},{'experiment':{'id':2,'name':'test2','type':'user','started_at':null,'completed_at':null,'completed_status':null}}]"
  def index
    @experiments = Experiment.includes(:experiment_definition).where("experiment_definitions.experiment_type"=>"user").load
    respond_to do |format|
      format.json { render "index", :status => :ok }
    end
  end
  
  api :POST, "/experiments", "Create an experiment"
  param_group :experiment
  description "when experiment is created, default protocol will be created"
  example "{'experiment':{'id':1,'name':'test','type':'user','started_at':null,'completed_at':null,'completed_status':null,'protocol':{'id':1,'lid_temperature':'110.0','stages':[{'stage':{'id':1,'stage_type':'holding','name':'Holding Stage','num_cycles':1,'steps':[{'step':{'id':1,'name':'Step 1','temperature':'95.0','hold_time':180,'ramp':{'id':1,'rate':'100.0','max':true}}}]}},{'stage':{'id':2,'stage_type':'cycling','name':'Cycling Stage','num_cycles':40,'steps':[{'step':{'id':2,'name':'Step 2','temperature':'95.0','hold_time':30,'ramp':{'id':2,'rate':'100.0','max':true}}},{'step':{'id':3,'name':'Step 2','temperature':'60.0','hold_time':30,'ramp':{'id':3,'rate':'100.0','max':true}}}]}},{'stage':{'id':3,'stage_type':'holding','name':'Holding Stage','num_cycles':1,'steps':[{'step':{'id':4,'name':'Step 1','temperature':'4.0','hold_time':0,'ramp':{'id':4,'rate':'100.0','max':true}}}]}}]}}}"
  def create
    if params[:experiment][:guid].nil?
      experiment_definition = ExperimentDefinition.new(:name=>params[:experiment][:name], :experiment_type=>ExperimentDefinition::TYPE_USER_DEFINED)
      experiment_definition.protocol_params = params[:experiment][:protocol]
    else
      experiment_definition = ExperimentDefinition.where("guid=?", params[:experiment][:guid]).first
    end
    @experiment = Experiment.new
    @experiment.experiment_definition = experiment_definition
    ret = @experiment.save
    respond_to do |format|
      format.json { render "fullshow", :status => (ret)? :ok : :unprocessable_entity}
    end
  end
  
  api :PUT, "/experiments/:id", "Update an experiment"
  param_group :experiment
  example "{'experiment':{'id':1,'name':'test','type':'user','started_at':null,'completed_at':null,'completed_status':null}}"
  def update
    if @experiment == nil || !@experiment.experiment_definition.editable? #if experiment has been run, the name is still editable
      render json: {errors: "The experiment is not editable"}, status: :unprocessable_entity
      return
    end
    ret = @experiment.experiment_definition.update_attributes(experiment_params)
    respond_to do |format|
      format.json { render "show", :status => (ret)? :ok :  :unprocessable_entity}
    end
  end
  
  api :POST, "/experiments/:id/copy", "Copy an experiment"
  see "experiments#create", "json response"
  def copy
    old_experiment = Experiment.includes(:experiment_definition).find_by_id(params[:id])
    experiment_definition = old_experiment.experiment_definition.copy(params[:experiment]? experiment_params : nil)
    @experiment = Experiment.new
    @experiment.experiment_definition = experiment_definition
    ret = @experiment.save
    respond_to do |format|
      format.json { render "fullshow", :status => (ret)? :ok :  :unprocessable_entity}
    end
  end
  
  api :GET, "/experiments/:id", "Show an experiment"
  see "experiments#create", "json response"
  def show
    @experiment.experiment_definition.protocol.stages.load
    respond_to do |format|
      format.json { render "fullshow", :status => (@experiment)? :ok :  :unprocessable_entity}
    end
  end
  
  api :DELETE, "/experiments/:id", "Destroy an experiment"
  def destroy
    ret = @experiment.destroy
    respond_to do |format|
      format.json { render "destroy", :status => (ret)? :ok :  :unprocessable_entity}
    end
  end
  
  api :GET, "/experiments/:id/temperature_data?starttime=xx&endtime=xx&resolution=xx", "Retrieve temperature data"
  param :starttime, Integer, :desc => "0 means start of the experiment, in ms", :required => true
  param :endtime, Integer, :desc => "if not specified, it returns everything to the end of the experiment, in ms"
  param :resolution, Integer, :desc => "Include data points for every x milliseconds. Must be a multiple of 1000 ms"
  def temperature_data
    @temperatures =  @experiment.temperature_logs.with_range(params[:starttime], params[:endtime], params[:resolution])
    respond_to do |format|
      format.json { render "temperature_data", :status => :ok}
    end
  end

  api :GET, "/experiments/:id/amplification_data?raw=false&background=true&baseline=true&cq=true&step_id[]=43&step_id[]=44", "Retrieve amplification data"
  example "{'partial':false, 'total_cycles':40, 'steps':['step_id':2,
            'amplification_data':[['channel', 'well_num', 'cycle_num', 'background_subtracted_value', 'baseline_subtracted_value', 'fluorescence_value'], [1, 1, 1, 25488, -2003, 86], [1, 1, 2, 53984, -409, 85]],
            'cq':[['channel', 'well_num', 'cq'], [1, 1, 12.11], [1, 2, 15.77], [1, 3, null]]]}"
  def amplification_data
    params[:raw] = params[:raw].to_bool if !params[:raw].nil?
    params[:background] = params[:background].to_bool if !params[:background].nil?
    params[:baseline] = params[:baseline].to_bool if !params[:baseline].nil?
    params[:cq] = params[:cq].to_bool if !params[:cq].nil?
    
    if params[:step_id].nil? && params[:ramp_id].nil?
      #first step that collects data will be returned, if none of the steps can be found, first ramp that collect data will be returned
      params[:raw] = false if params[:raw].nil?
      params[:background] = true if params[:background].nil?
      params[:baseline] = true if params[:baseline].nil?
      params[:cq] = true if params[:cq].nil?
    else #if step_id is specified, only raw data is returned
      params[:raw] = true
      params[:background] = false
      params[:baseline] = false
      params[:cq] = false
    end
    
    if @experiment
      if @experiment.ran?
        @first_stage_collect_data = Stage.collect_data(@experiment.experiment_definition_id).first
        if !@first_stage_collect_data.blank?
          last_cycle = FluorescenceDatum.last_cycle(@experiment.id, @first_stage_collect_data.id)
          @partial = (@experiment.running? && last_cycle < @first_stage_collect_data.num_cycles)
          analyze_required = params[:background] == true || params[:baseline] == true || params[:cq] == true
          if analyze_required
            begin
              task_submitted = background_calculate_amplification_data(@experiment, @first_stage_collect_data.id)
            rescue => e
              render :json=>{:errors=>e.to_s}, :status => 500
              return
            end
            
            if @partial == false
              @partial = FluorescenceDatum.new_data_generated?(@experiment.id, @first_stage_collect_data.id)
            end
            
            if !stale?(etag: generate_etag(@partial, AmplificationDatum.maxid(@experiment.id, @first_stage_collect_data.id)))
              #render 304 Not Modified
              return
            end

            @amplification_data = AmplificationDatum.retrieve(@experiment.id, @first_stage_collect_data.id)
            @cts = AmplificationCurve.retrieve(@experiment.id, @first_stage_collect_data.id)

            if @amplification_data.blank? && !task_submitted.nil?
              #no data but background task is submitted
              render :nothing => true, :status => (task_submitted)? 202 : 503
              return
            elsif !@amplification_data.blank?
              #set etag
              fresh_when(:etag => generate_etag(@partial, @amplification_data.last.id))
            end
          end
 
          if params[:raw] == true
            if !analyze_required && !stale?(etag: generate_etag(@partial, last_cycle))
              #render 304 Not Modified
              return
            end
            
            #construct OR clause
            conditions = String.new
            wheres = Array.new
            Constants::KEY_NAMES.each do |keyname|
              keyvalue = params[keyname.to_sym]
              if keyvalue
                conditions << " OR " unless conditions.length == 0
                conditions << "#{keyname} IN (?)"
                if keyvalue.is_a? Array
                  wheres << keyvalue
                else
                  wheres << keyvalue.to_i
                end
              end
            end
            wheres.insert(0, conditions) if !conditions.blank?
            #logger.info ("**********#{wheres.join(",")}")
            #query to database
            if !wheres.blank?
              fluorescence_data = FluorescenceDatum.order(Constants::KEY_NAMES.join(", ")).for_experiment(@experiment.id).where(wheres)
            else
              fluorescence_data = FluorescenceDatum.for_stage(@first_stage_collect_data.id).for_experiment(@experiment.id)
            end
            
            if !analyze_required && !fluorescence_data.blank?
              #set etag
              fresh_when(:etag => generate_etag(@partial, fluorescence_data.last.cycle_num))
            end
          end
        end
        
        if !@amplification_data.blank? 
          if !fluorescence_data.blank?
            #amplification_data only have one step
            fluorescence_offset = 0
            if !@amplification_data[0].sub_type.nil?
              sub_type = (@amplification_data[0].sub_type + "_id").to_sym
              sub_id = @amplification_data[0].send(sub_type)
              while fluorescence_offset < fluorescence_data.count && fluorescence_data[fluorescence_offset].send(sub_type) != sub_id do
                fluorescence_offset += 1
              end
            end
            @amplification_data.each_index do |i|
              @amplification_data[i].fluorescence_value = fluorescence_data[fluorescence_offset+i].fluorescence_value
            end
          end
        elsif !fluorescence_data.blank?
          @amplification_data = fluorescence_data
        end
        
        attributes = []
        attributes << "background_subtracted_value" if params[:background] == true
        attributes << "baseline_subtracted_value" if params[:baseline] == true
        attributes << "fluorescence_value" if params[:raw] == true
        @amplification_data_group = group_by_keynames(@amplification_data, attributes, (params[:cq] == true)? @cts : nil)

        respond_to do |format|
          format.json { render "amplification_data", :status => :ok}
        end
      else
        render :json=>{:errors=>"experiment has not run yet"}, :status => 500
      end
    else
      render :json=>{:errors=>"experiment not found"}, :status => :not_found
    end
  end
  
  api :GET, "/experiments/:id/melt_curve_data?raw=false&normalized=true&derivative=true&tm=true&ramp_id[]=43&ramp_id[]=44", "Retrieve melt curve data"
  example "{'partial':false, 'ramps':['ramp_id':22,
            'melt_curve_data':[{'well_num':1, 'temperature':[0,1,2,3,4,5], 'normalized_data':[0,1,2,3,4,5], 'derivative_data':[0,1,2,3,4,5], 'tm':[1,2,3], 'area':[2,4,5]},
                               {'well_num':2, 'temperature':[0,1,2,3,4,5], 'normalized_data':[0,1,2,3,4,5], 'derivative_data':[0,1,2,3,4,5], 'tm':[1,2,3], 'area':[2,4,5]}]]}"
  def melt_curve_data
    params[:raw] = params[:raw].to_bool if !params[:raw].nil?
    params[:normalized] = params[:normalized].to_bool if !params[:normalized].nil?
    params[:derivative] = params[:derivative].to_bool if !params[:derivative].nil?
    params[:tm] = params[:tm].to_bool if !params[:tm].nil?
    
    if params[:ramp_id].nil?
      #first step that collects data will be returned, if none of the steps can be found, first ramp that collect data will be returned
      params[:raw] = false if params[:raw].nil?
      params[:normalized] = true if params[:normalized].nil?
      params[:derivative] = true if params[:derivative].nil?
      params[:tm] = true if params[:tm].nil?
    else #if ramp_id is specified, only raw data is returned
      params[:raw] = true
      params[:normalized] = false
      params[:derivative] = false
      params[:tm] = false
    end
    
    if @experiment
      if @experiment.ran?
        @first_stage_meltcurve_data = Stage.melt_curve(@experiment.experiment_definition_id).first
        if !@first_stage_meltcurve_data.blank?
          @partial = @experiment.running?
          analyze_required = params[:normalized] == true || params[:derivative] == true || params[:tm] == true
          if analyze_required
            begin
              task_submitted = background_calculate_melt_curve_data(@experiment, @first_stage_meltcurve_data.id)
            rescue => e
              render :json=>{:errors=>e.to_s}, :status => 500
              return
            end
            
            if @partial == false
              @partial = MeltCurveDatum.new_data_generated?(@experiment, @first_stage_meltcurve_data.id) != nil
            end
          
            if !@experiment.cached_temperature.nil? && !stale?(etag: generate_etag(@partial, @experiment.cached_temperature))
              #render 304 Not Modified
              return
            end

            @melt_curve_data = CachedMeltCurveDatum.retrieve(@experiment.id, @first_stage_meltcurve_data.id)

            if @melt_curve_data.blank? && !task_submitted.nil?
              #no data but background task is submitted
              render :nothing => true, :status => (task_submitted)? 202 : 503
              return
            elsif !@experiment.cached_temperature.nil?
              #set etag
              fresh_when(:etag => generate_etag(@partial, @experiment.cached_temperature))
            end
          end
 
          if params[:raw] == true
            if !analyze_required && !stale?(etag: generate_etag(@partial, MeltCurveDatum.maxid(@experiment.id, @first_stage_meltcurve_data.id)))
              #render 304 Not Modified
              return
            end
            
            #construct OR clause
            conditions = String.new
            wheres = Array.new
            keyvalue = params[:ramp_id]
            if keyvalue
              conditions << " OR " unless conditions.length == 0
              conditions << "ramp_id IN (?)"
              if keyvalue.is_a? Array
                wheres << keyvalue
              else
                wheres << keyvalue.to_i
              end
            end
            wheres.insert(0, conditions) if !conditions.blank?
            #logger.info ("**********#{wheres.join(",")}")
            
            #query to database
            if !wheres.blank?
              raw_data = MeltCurveDatum.for_experiment(@experiment.id).where(wheres).group_by_well.all
            else
              raw_data = MeltCurveDatum.for_stage(@first_stage_meltcurve_data.id).for_experiment(@experiment.id).group_by_well.all
            end
            
            if !analyze_required && !raw_data.blank?
              #set etag
              max_id = raw_data.max_by(&:id).id
              #logger.info("**************max_id=#{max_id}")
              fresh_when(:etag => generate_etag(@partial, max_id))
            end
          end
        end
        
        if !@melt_curve_data.blank? 
          if !raw_data.blank?
            #melt_curve_data only have one ramp
            ramp_id = @melt_curve_data[0].ramp_id
            fluorescence_offset = 0
            while fluorescence_offset < raw_data.count && raw_data[fluorescence_offset].ramp_id != ramp_id do
              fluorescence_offset += 1
            end
            @melt_curve_data.each_index do |i|
              @melt_curve_data[i].fluorescence_data = raw_data[fluorescence_offset+i].fluorescence_data
            end
          end
        elsif !raw_data.blank?
          @melt_curve_data = raw_data
        end
        
        if !@melt_curve_data.blank?
          @melt_curve_data_group = []
          melt_curve_data_hash = @melt_curve_data.group_by { |obj| obj.ramp_id }
          melt_curve_data_hash.each do |ramp_id, data_array|
            data_array.each do |data|
              if params[:raw] == false && data.respond_to?(:fluorescence_data)
                data.instance_eval 'undef :fluorescence_data'
              end
              if params[:normalized] == false && data.respond_to?(:normalized_data)
                data.instance_eval 'undef :normalized_data'
              end
              if params[:derivative] == false && data.respond_to?(:derivative_data)
                data.instance_eval 'undef :derivative_data'
              end
              if params[:tm] == false && data.respond_to?(:tm)
                data.instance_eval 'undef :tm'
                data.instance_eval 'undef :area'
              end
            end
            @melt_curve_data_group << OpenStruct.new(:ramp_id=>ramp_id, :melt_curve_data=>data_array)
          end
        end
        
        respond_to do |format|
          format.json { render "melt_curve_data", :status => :ok}
        end
      else
        render :json=>{:errors=>"experiment has not run yet"}, :status => 500
      end
    else
      render :json=>{:errors=>"experiment not found"}, :status => :not_found
    end
  end

  api :GET, "/experiments/:id/export", "zip temperature, amplification and meltcurv csv files"
  def export
    t = Tempfile.new("tmpexport_#{request.remote_ip}")
    begin
      Zip::OutputStream.open(t.path) do |out|
        if request.method != "HEAD"
          out.put_next_entry("qpcr_experiment_#{(@experiment)? @experiment.name : "null"}/temperature_log.csv")
          out.write TemperatureLog.as_csv(params[:id])
        end
      
        first_stage_collect_data = Stage.collect_data(@experiment.experiment_definition_id).first
        if first_stage_collect_data
          begin
            task_submitted = background_calculate_amplification_data(@experiment, first_stage_collect_data.id)
            amplification_data = AmplificationDatum.retrieve(@experiment, first_stage_collect_data.id)
            
            if !task_submitted.nil? && (!@experiment.running? || amplification_data.blank?)
              #background task is submitted 
              #if experiment is finished, wait for the task to complete
              #if amplification_data is empty, wait for the task to complete
              t.close
              render :nothing => true, :status => (task_submitted)? 202 : 503
              return
            end
          rescue => e
            logger.error("export amplification data failed: #{e}")
          end
          
          if request.method == "HEAD"
            amplification_data = nil
          else
            cts = AmplificationCurve.retrieve(@experiment, first_stage_collect_data.id)
            fluorescence_data = FluorescenceDatum.for_stage(first_stage_collect_data.id).for_experiment(@experiment.id)
          end
        end
      
        if amplification_data
          out.put_next_entry("qpcr_experiment_#{(@experiment)? @experiment.name : "null"}/amplification.csv")
          columns = ["channel", "well_num", "cycle_num"]
          fluorescence_index = 0
          csv_string = CSV.generate do |csv|
            csv << ["baseline_subtracted_value", "background_subtracted_value", "fluorescence_value"]+columns
            amplification_data.each do |data|
              while (fluorescence_index < fluorescence_data.length && 
                    !(fluorescence_data[fluorescence_index].channel == data.channel && 
                      fluorescence_data[fluorescence_index].well_num == data.well_num &&
                      fluorescence_data[fluorescence_index].cycle_num == data.cycle_num)) do
                    fluorescence_index += 1
              end
              fluorescence_value = (fluorescence_index < fluorescence_data.length)? fluorescence_data[fluorescence_index].fluorescence_value : nil
              csv << [data.baseline_subtracted_value, data.background_subtracted_value, fluorescence_value]+data.attributes.values_at(*columns)
              fluorescence_index += 1
            end
          end
          out.write csv_string
        end

        if cts
          out.put_next_entry("qpcr_experiment_#{(@experiment)? @experiment.name : "null"}/cq.csv")
          csv_string = CSV.generate do |csv|
            csv << ["channel", "well_num", "cq"];
            cts.each do |ct|
              csv << [ct.channel, ct.well_num, ct.ct]
            end
          end
          out.write csv_string
        end

        first_stage_meltcurve_data = Stage.melt_curve(@experiment.experiment_definition_id).first
        if first_stage_meltcurve_data
          begin
            task_submitted = background_calculate_melt_curve_data(@experiment, first_stage_meltcurve_data.id)
            melt_curve_data = CachedMeltCurveDatum.retrieve(@experiment.id, first_stage_meltcurve_data.id)
            
            if !task_submitted.nil? && (!@experiment.running? || melt_curve_data.blank?)
              #background task is submitted
              #if experiment is finished, wait for the task to complete
              #if amplification_data is empty, wait for the task to complete
              t.close
              render :nothing => true, :status => (task_submitted)? 202 : 503
              return
            end
          rescue => e
            logger.error("export melt curve data failed: #{e}")
          end
          
          if request.method == "HEAD"
            melt_curve_data = nil
          end
        end

        if melt_curve_data
          out.put_next_entry("qpcr_experiment_#{(@experiment)? @experiment.name : "null"}/melt_curve_data.csv")
          columns = ["channel", "well_num", "temperature", "normalized_data", "derivative_data"]
          out.write columns.to_csv
          melt_curve_data.each do |data|
            data.temperature.each_index do |index|
              out.write "#{data.channel}, #{data.well_num}, #{data.temperature[index]}, #{data.normalized_data[index]}, #{data.derivative_data[index]}\r\n"
            end
          end

          out.put_next_entry("qpcr_experiment_#{(@experiment)? @experiment.name : "null"}/melt_curve_analysis.csv")
          columns = ["channel", "well_num", "Tm1", "Tm2", "Tm3", "Tm4", "area1", "area2", "area3", "area4"]
          csv_string = CSV.generate do |csv|
            csv << columns
            melt_curve_data.each do |data|
              tm_arr = Array.new(4)
              data.tm.each_index{|i| tm_arr[i] = data.tm[i]}
              area_arr = Array.new(4)
              data.area.each_index{|i| area_arr[i] = data.area[i]}
              csv << [data.channel, data.well_num]+tm_arr+area_arr
            end
          end
        
          out.write csv_string
        end
      end
      send_file t.path, :type => 'application/zip', :disposition => 'attachment', :filename => "export.zip"
    ensure
      t.close
    end
  end
  
  def analyze
    if @experiment && !@experiment.experiment_definition.guid.blank?
      if @experiment.completion_status == "success"
        cached_data = CachedAnalyzeDatum.where(:experiment_id=>@experiment.id).first
        if cached_data.nil? #no cache data found
          begin
            task_submitted = background_analyze_data(@experiment)
            render :nothing => true, :status => (task_submitted)? 202 : 503
          rescue  => e
            render :json=>{:errors=>e.to_s}, :status => 500
          end
        else
          render :json=>cached_data.analyze_result
        end
      elsif !@experiment.ran?
        render :json=>{:errors=>"Please run the experiment before calling analyze"}, :status => 500
      elsif !@experiment.running?
        render :json=>{:errors=>"Please wait for the experiment to be completed before calling analyze"}, :status => 500
      else
        render :json=>{:errors=>"experiment cannot be analyzed because it wasn't completed successfully (status=#{completion_status})"}, :status => 500
      end
    else
      render :json=>{:errors=>"experiment not found"}, :status => :not_found
    end
  end
  
  protected
  
  def get_experiment
    @experiment = Experiment.find_by_id(params[:id]) if @experiment.nil?
  end
  
  def generate_etag(partial, tag)
    return "partial:#{partial} tag:#{tag}"
  end
 
  def background_calculate_amplification_data(experiment, stage_id)
    return nil if !FluorescenceDatum.new_data_generated?(experiment.id, stage_id)
    experiment.experiment_definition #load experiment_definition before go to background thread
    return background("amplification", experiment.id) do
      amplification_data, cts = calculate_amplification_data(experiment, stage_id, experiment.calibration_id)
      #update cache
      AmplificationDatum.import amplification_data, :on_duplicate_key_update => [:background_subtracted_value,:baseline_subtracted_value]
      AmplificationCurve.import cts, :on_duplicate_key_update => [:ct]
    end
  end
  
  def calculate_amplification_data(experiment, stage_id, calibration_id)
   # sleep(10)
  #  return  [AmplificationDatum.new(:experiment_id=>experiment_id, :stage_id=>stage_id, :channel=>1, :well_num=>1, :cycle_num=>1, :background_subtracted_value=>1001, :baseline_subtracted_value=>102)], [AmplificationCurve.new(:experiment_id=>experiment_id, :stage_id=>stage_id, :channel=>1, :well_num=>1, :ct=>10)]
    step = Step.collect_data(stage_id).first
    if step
      sub_id = step.id
      sub_type = "step"
    else
      ramp = Ramp.collect_data(stage_id).first
      if ramp
        sub_id = ramp.id
        sub_type = "ramp"
      else
        return nil, nil
      end
    end
      
    config   = Rails.configuration.database_configuration
    connection = Rserve::Connection.new(:timeout=>RSERVE_TIMEOUT)
    start_time = Time.now
    begin
      results = connection.eval("tryCatchError(get_amplification_data, '#{config[Rails.env]["username"]}', '#{(config[Rails.env]["password"])? config[Rails.env]["password"] : ""}', '#{(config[Rails.env]["host"])? config[Rails.env]["host"] : "localhost"}', #{(config[Rails.env]["port"])? config[Rails.env]["port"] : 3306}, '#{config[Rails.env]["database"]}', #{experiment.id}, list(#{sub_type}_id=#{sub_id}), #{calibrate_info(calibration_id)})")
    rescue  => e
      logger.error("Rserve error: #{e}")
      kill_process("Rserve") if e.is_a? Rserve::Talk::SocketTimeoutError
      raise e
    ensure
      connection.close
    end
    logger.info("R code time #{Time.now-start_time}")
    start_time = Time.now
    results = results.to_ruby
    amplification_data = []
    cts = []
    if !results.blank?
      raise results["message"] if !results["message"].blank? #catched error
      (0...results[0].length).each do |channel|
         background_subtracted_results = results[0][channel]
         baseline_subtracted_results = results[1][channel]
         if background_subtracted_results.is_a? Array
           num_cycles = 1
           num_wells = background_subtracted_results.length-1
         else
           num_cycles = background_subtracted_results.row_size
           num_wells = background_subtracted_results.column_size-1
         end
         (0...num_wells).each do |well_num|
           (0...num_cycles).each do |cycle_num|
             background_subtracted_value = (background_subtracted_results.is_a? Array)? background_subtracted_results[well_num+1] : background_subtracted_results[cycle_num, well_num+1]
             baseline_subtracted_value = (baseline_subtracted_results.is_a? Array)? baseline_subtracted_results[well_num] : baseline_subtracted_results[cycle_num, well_num]
             amplification_data << AmplificationDatum.new(:experiment_id=>experiment.id, :stage_id=>stage_id, :sub_type=>sub_type, :sub_id=>sub_id, :channel=>channel+1, :well_num=>well_num+1, :cycle_num=>cycle_num+1, :background_subtracted_value=>background_subtracted_value, :baseline_subtracted_value=>baseline_subtracted_value)
           end
         end
         ct_results = results[2][channel]
         (0...ct_results.column_size).each do |well_num|
           cts << AmplificationCurve.new(:experiment_id=>experiment.id, :stage_id=>stage_id, :channel=>channel+1, :well_num=>well_num+1, :ct=>ct_results[0,well_num])
         end
      end
      #amplification_data.sort_by!{|x| [x.channel,x.well_num,x.cycle_num]}
    end
    logger.info("Rails code time #{Time.now-start_time}")
    return amplification_data, cts
  end

  def background_calculate_melt_curve_data(experiment, stage_id)
    new_data = MeltCurveDatum.new_data_generated?(experiment, stage_id)
    return nil if new_data.nil?
    return background("meltcurve", experiment.id) do
      melt_curve_data = calculate_melt_curve_data(experiment, stage_id, experiment.calibration_id)
      #update cache
      CachedMeltCurveDatum.import melt_curve_data, :on_duplicate_key_update => [:temperature_text, :normalized_data_text, :derivative_data_text, :tm_text, :area_text]
      #update cached_temperature
      if melt_curve_data.last
        cached_temperature = (experiment.running?)? melt_curve_data.last.temperature.last : new_data.temperature
        if cached_temperature
          experiment.update_attributes(:cached_temperature=>cached_temperature)
        end
      end
    end
  end
  
  def calculate_melt_curve_data(experiment, stage_id, calibration_id)
  #  sleep(10)
  #  return [CachedMeltCurveDatum.new({:experiment_id=>experiment_id, :stage_id=>stage_id, :channel=>1, :well_num=>1, :temperature=>[121,122], :fluorescence_data=>[1001, 1002], :derivative=>[3,4], :tm=>[1,2,3], :area=>[1,2,5]})]
    
    config   = Rails.configuration.database_configuration
    connection = Rserve::Connection.new(:timeout=>RSERVE_TIMEOUT)
    start_time = Time.now
    begin
      results = connection.eval("tryCatchError(process_mc, '#{config[Rails.env]["username"]}', '#{(config[Rails.env]["password"])? config[Rails.env]["password"] : ""}', '#{(config[Rails.env]["host"])? config[Rails.env]["host"] : "localhost"}', #{(config[Rails.env]["port"])? config[Rails.env]["port"] : 3306}, '#{config[Rails.env]["database"]}', #{experiment.id}, #{stage_id}, #{calibrate_info(calibration_id)}, #{"qt_prob=0.1, max_normd_qtv=0.9" if experiment.experiment_definition.guid == "thermal_consistency"})")
    rescue  => e
      logger.error("Rserve error: #{e}")
      kill_process("Rserve") if e.is_a? Rserve::Talk::SocketTimeoutError
      raise e
    ensure
      connection.close
    end
    logger.info("R code time #{Time.now-start_time}")
    start_time = Time.now
    results = results.to_ruby
    ramp = Ramp.collect_data(stage_id).first
    melt_curve_data = []
    if !results.blank?
      raise results["message"] if !results["message"].blank? #catched error
      (0...results.length).each do |channel|
        results[channel].each_index do |i|
          results_per_well = results[channel][i]
          hash = CachedMeltCurveDatum.new({:experiment_id=>experiment.id, :stage_id=>stage_id, :ramp_id=>(ramp)? ramp.id : nil, :channel=>channel+1, :well_num=>i+1, :temperature=>results_per_well[0][0], :normalized_data=>results_per_well[0][1], :derivative_data=>results_per_well[0][2], :tm=>(results_per_well[1][0].blank?)? [] : (results_per_well[1][0].is_a? Array)? results_per_well[1][0] : [results_per_well[1][0]], :area=>(results_per_well[1][1].blank?)? [] : (results_per_well[1][1].is_a? Array)? results_per_well[1][1] : [results_per_well[1][1]]})
          melt_curve_data << hash
        end
      end
    end 
    logger.info("Rails code time #{Time.now-start_time}")
    return melt_curve_data
  end

  def background_analyze_data(experiment)
    background("analyze", experiment.id) do
      config   = Rails.configuration.database_configuration
      connection = Rserve::Connection.new(:timeout=>RSERVE_TIMEOUT)
      begin
        connection.eval("source(\"#{Rails.configuration.dynamic_file_path}/#{experiment.experiment_definition.guid}/analyze.R\")")
        response = connection.eval("tryCatchError(analyze, '#{config[Rails.env]["username"]}', '#{(config[Rails.env]["password"])? config[Rails.env]["password"] : ""}', '#{(config[Rails.env]["host"])? config[Rails.env]["host"] : "localhost"}', #{(config[Rails.env]["port"])? config[Rails.env]["port"] : 3306}, '#{config[Rails.env]["database"]}', #{experiment.id}, #{calibrate_info(experiment.calibration_id)}#{", qt_prob=0.1, max_normd_qtv=0.9" if experiment.experiment_definition.guid == "thermal_consistency"})").to_ruby
        new_data = CachedAnalyzeDatum.new(:experiment_id=>experiment.id, :analyze_result=>response.to_s)
      rescue  => e
        logger.error("Rserve error: #{e}")
        kill_process("Rserve") if e.is_a? Rserve::Talk::SocketTimeoutError
        raise e
      ensure
        connection.close
      end
      raise response["message"] if response && response.is_a?(Array) && !response["message"].blank? #catched error

      #update analyze status
      if experiment.diagnostic?
        experiment.update_attributes(:analyze_status=>(response.include?("false"))? "failed" : "success")
      end
      #update cache
      CachedAnalyzeDatum.import [new_data], :on_duplicate_key_update => [:analyze_result]
    end
  end
  
  def calibrate_info(calibration_id)
    protocol = Protocol.includes(:stages).where("protocols.experiment_definition_id=(SELECT experiment_definition_id from experiments where experiments.id=#{calibration_id} LIMIT 1)").first
    if protocol && protocol.stages[0]
      water_index = protocol.stages[0].steps.find_index{|item| item.name == "Water"}
      step_water = (!water_index.nil?)? protocol.stages[0].steps[water_index].id : nil
      if Device.dual_channel?
        if calibration_id == 1
          channel_1_index = protocol.stages[0].steps.find_index{|item| item.name == "Signal"}
          channel_2_index = channel_1_index
        else
          channel_1_index = protocol.stages[0].steps.find_index{|item| item.name == "FAM"}
          channel_2_index = protocol.stages[0].steps.find_index{|item| item.name == "HEX"}
          baseline_index = protocol.stages[0].steps.find_index{|item| item.name == "Baseline"}
        end
      else
        channel_1_index = protocol.stages[0].steps.find_index{|item| item.name == "Signal"}
        channel_2_index = nil
      end
      step_channel_1 = (!channel_1_index.nil?)? protocol.stages[0].steps[channel_1_index].id : nil
      step_channel_2 = (!channel_2_index.nil?)? protocol.stages[0].steps[channel_2_index].id : nil
      step_baseline = (!baseline_index.nil?)? protocol.stages[0].steps[baseline_index].id : nil
      result = "list(water=list(calibration_id=#{calibration_id},step_id=#{step_water}), channel_1=list(calibration_id=#{calibration_id},step_id=#{step_channel_1}) \
              #{(step_channel_2)? ", channel_2=list(calibration_id="+calibration_id.to_s+",step_id="+step_channel_2.to_s+")" : ""} \
              #{(step_baseline)? ", baseline=list(calibration_id="+calibration_id.to_s+",step_id="+step_baseline.to_s+")" : ""})"
    end
    result
  end

  def background(action, experiment_id, &block)
    if @@background_last_task && @@background_last_task.match?(action, experiment_id)
      error = @@background_last_task.complete_result
      @@background_last_task = nil
      raise error
    elsif @@background_task == nil
      @@background_task = BackgroundTask.new(action, experiment_id, nil)
      Thread.new do
        begin
          yield
        rescue => e
          logger.error ("background task error: #{e}")
          @@background_task.complete_result = e
          @@background_last_task = @@background_task
        ensure
          ActiveRecord::Base.connection.close
          @@background_task = nil
        end
      end
      return true #background process is started
    elsif @@background_task.match?(action, experiment_id)
      return true #@@background_task process is still in progress
    else
      return false #there is already another background process, return resource unavailable
    end
  end
  
  def group_by_keynames(data, data_attributes, cqs)
    return nil if data.nil?
    
    keyname = nil
    key = nil
    data_array = nil
    group = Array.new
    column_names = ["channel","well_num","cycle_num"]+data_attributes
    
    data.each do |node|
      Constants::KEY_NAMES.each do |newkeyname|
        newkeyname = newkeyname.to_sym
        sub_id = node.send(newkeyname)
        if sub_id != nil && sub_id != key
          group << OpenStruct.new(keyname=>key, :amplification_data=>data_array) if key != nil
          keyname = newkeyname
          key = sub_id
          data_array = []
          data_array << column_names
        end
      end
      data_array << node.attributes.values_at(*column_names)
    end

    if key != nil
      elem = OpenStruct.new(keyname=>key, :amplification_data=>data_array)
      if !cqs.blank?
        elem.cq = [["channel","well_num","cq"]]+cqs.map {|cq| [cq.channel,cq.well_num,cq.ct]} 
      end
      group << elem
    end
    
    return group
  end
end
