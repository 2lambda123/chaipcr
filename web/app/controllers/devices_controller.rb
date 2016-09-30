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
require "net/http"
require 'digest/md5'
require 'json'
require 'zip'

class DevicesController < ApplicationController
  include ParamsHelper
  
  skip_before_action :verify_authenticity_token, :except=>[:root_password]
  before_filter :allow_cors, :except=>[:root_password]
  before_filter :ensure_authenticated_user, :except=>[:show, :serial_start, :update, :clean, :unserialize, :login, :software_update, :empty]
  
  respond_to :json
  
  resource_description { 
    formats ['json']
  }
  
  def empty
     render :nothing => true
  end
  
  api :GET, "/device", "return device specific information"
  example "{'serial_number':'1234789127894212','model_number':'M2342JA','processor_architecture':'armv7l','software':{'version':'1.0.0','platform':'S0100'}}"
  description <<-EOS
    ==response json format
    ===serial_number
    serial number of the device
    ===model_number
    hardware model number of the device 
    ===processor_architecture
    device processor architecture
    ===software version
    current software version
    ===software platform
    current software platform
  EOS
  def show
    result_hash = Hash.new
    if Device.valid?
      result_hash["serial_number"] = Device.serial_number
      result_hash["device_signature"] = Device.device_signature
      result_hash["model_number"] = Device.model_number
      result_hash["processor_architecture"] = Device.processor_architecture
    end
    if DeviceConfiguration.valid?
      result_hash["software"] = DeviceConfiguration.software
    end
    result_hash["software_release_variant"] = Setting.software_release_variant
    
    render json: result_hash.to_json, status: :ok
  end
  
  api :GET, "/capabilities", "return device capabilities"
  example "{'capabilities':{'plate':{'rows':2,'columns':8,'min_volume_ul':5,'max_volume_ul':100},'optics':{'excitation_channels':[{'begin_wavelength':462,'end_wavelength':490}],'emission_channels':[{'begin_wavelength':510,'end_wavelength':700}]},'storage':{'microsd_size_gb':8,'emmc_size_gb':4}},'thermal':{'lid':{'max_temp_c':120},'block':{'min_temp_c':4,'max_temp_c':100}}}"
  def capabilities
    result_hash = Hash.new
    if Device.valid?
      result_hash["capabilities"] = Device.capabilities
    end
    if DeviceConfiguration.valid?
      result_hash["thermal"] = DeviceConfiguration.thermal
    end
    render json: result_hash.to_json, status: :ok
  end
  
  api :GET, "/device/status", "status of the machine"
  def status
    url = URI.parse("http://localhost:8000/status?access_token=#{authentication_token}")
    begin
      response = Net::HTTP.get_response(url)
      render :json=>response.body, :status=>response.code
    rescue  => e
      render json: {errors: "reatime server port 8000 cannot be reached: #{e}"}, status: 500
    end
  end
  
  api :PUT, "/device/root_password", "Set root password"
  param :password, String, :desc => "password to set", :required=>true
  def root_password
    system("printf '#{params[:password]}\n#{params[:password]}\n' | passwd")
    render json: {response: "Root password is set properly"}, status: :ok
  end
   
  def serial_start
    if Device.exists?
      if Device.serial_number.blank?
        # make sure all the diagnostic experiments are passed
        @experiments = Experiment.includes(:experiment_definition).where(id: Experiment.select("MAX(experiments.id)").joins(:experiment_definition).where("experiment_definitions.experiment_type = ? AND experiments.completion_status != ?", ExperimentDefinition::TYPE_DIAGNOSTIC, "aborted").group("experiment_definitions.id"))
        passed_diagnostics = Array.new
        for experiment in @experiments
          if experiment.diagnostic_passed?
            passed_diagnostics << experiment.experiment_definition.guid
          end
        end
        if (passed_diagnostics & ExperimentDefinition.diagnostic_guids).count != ExperimentDefinition.diagnostic_guids.count
          result = "<table style='width: 400px; color: black;'><tr><th>Test</th><th>Status</th></tr>"
          for test_guid in ExperimentDefinition.diagnostic_guids
            experiment_index = @experiments.index{|experiment| experiment.experiment_definition.guid == test_guid}
            if experiment_index == nil
              status = "Not performed"
            else
              status = (@experiments[experiment_index].diagnostic_passed?)? "Pass" : "Fail"
            end
            result += "<tr><td>#{test_guid}</td><td style='color:#{(status == "Pass")? "green" : "red"}'>#{status}</td></tr>"
          end
          result += "</table>"
          render json: {errors: "<p>Unable to serialize device: diagnostics not yet passed. Current status:</p>#{result}"}, status: 405
        else
          mac = retrieve_mac
          if !mac.blank?
            render json: {mac: mac, software_version: DeviceConfiguration.software_version, configuration_id: Device.configuration_id}
          elsif mac.blank?
            render json: {errors: "Device mac address not found"}, status: 500
          else
            render json: {errors: "Device configuration file is not found"}, status: 500
          end
        end
      else
        render json: {errors: "Device is already serialized (serial number = #{Device.serial_number})"}, status: 405
      end
    else
      render json: {errors: "Device is not configured"}, status: 405
    end
  end
  
  def update
    if Device.exists?
      if !Device.serial_number.blank?
        render json: {errors: "Device is already serialized (serial number = #{Device.serial_number})"}, status: 405
        return
      end
    end

    erase_data
    
    start_time = Time.now
    error = Device.write(request.body.read)
    if !error.blank?
      render json: {errors: error}, status: 400
      return
    end
    logger.info "device write: Time elapsed #{(Time.now - start_time)*1000} milliseconds"
    
    start_time = Time.now
    system("sync")
    logger.info "second sync: Time elapsed #{(Time.now - start_time)*1000} milliseconds"
    
    kill_process("realtime")
    
    render json: {response: "Device is programmed successfully"}, status: :ok
  end
  
  def clean
    if !Device.valid?
      render json: {errors: "Device file is not found or corrupted"}, status: 500
      return
    end
    if !Device.device_signature.blank? && Device.device_signature == params["signature"]
      erase_data
      render json: {response: "Device is cleaned successfully"}, status: :ok
    else
      render json: {errors: "Device cannot be cleaned because device signature doesn't match"}, status: 400
    end
  end
  
  def unserialize
    if !Device.valid?
      render json: {errors: "Device file is not found or corrupted"}, status: 500
      return
    end
    if !Device.device_signature.blank? && Device.device_signature == params["signature"]
      Device.unserialized!
      render json: {response: "Device is unserialized"}, status: :ok
    else
      render json: {errors: "Device cannot be unserialized because device signature doesn't match"}, status: 400
    end
  end

  def login
    if !Device.valid?
      render json: {errors: "Device file is not found or corrupted"}, status: 500
      return
    end
    if !Device.device_signature.blank? && Device.device_signature == params["signature"]
      render json: {url: login_path(:token=>User.maintenance_user.token)}, status: :ok
    else
      render json: {errors: "Device cannot be login because device signature doesn't match"}, status: 400
    end
  end
  
  api :GET, "/device/software_update", "query the software update meta data"
  example "{'upgrade':{'version':'1.0.1','release_date':null,'brief_description':'this is the brief description','full_description':'this is the full description'}}"
  def software_update
    @upgrade = Upgrade.first
    if @upgrade
      #no upgrade available if the upgrade version is the same as current software version
      @upgrade = nil if @upgrade.version == DeviceConfiguration.software_version
    end
    respond_to do |format|
      format.json { render "software_update", :status => :ok}
    end
  end
  
  api :POST, "/device/enable_support_access", "enable remote support access"
  def enable_support_access
    query_hash = Hash.new
    query_hash[:v] = 1
    query_hash[:model_number] = Device.model_number
    query_hash[:software_version] = DeviceConfiguration.software_version
    query_hash[:software_platform] = DeviceConfiguration.software["platform"]
    query_hash[:serial_number] = Device.serial_number
    #query_hash[:device_signature]
    
    #query cloud server for auth_token and ssh keys
    url = URI.parse("#{CLOUD_SERVER}/device/provision_support_access?#{query_hash.to_query}")
    begin
      response = Net::HTTP.get_response(url)
    rescue  => e
      render json: {errors: "chai cloud server #{CLOUD_SERVER} cannot be reached: #{e}"}, status: 500
      return
    end
    
    if response.code.to_i != 200 
      render json: {errors: "chai cloud server #{CLOUD_SERVER} provision_support_access fails (#{response.code}): #{response.body}"}, status: 500
      return
    end
    
    #setup ngrok
    json_response = JSON.parse(response.body)
    
    begin
      logger.info("replace /root/.ngrok2/ngrok.yml")
      File.open("/root/.ngrok2/ngrok.yml", 'w') {|f| f.write("authtoken: #{json_response["tunnel_authtoken"]}") }
    rescue  => e
      render json: {errors: "open ngrok.yml fails: #{e}"}, status: 500
      return
    end
    
    begin
      logger.info("replace /home/service/.ssh/authorized_keys")
      File.open("/home/service/.ssh/authorized_keys", 'w') {|f| f.write(json_response["ssh_access_key"]) }
    rescue  => e
      render json: {errors: "open .ssh/authorized_keys fails: #{e}"}, status: 500
      return
    end
        
    #kill ngrok
    kill_process("ngrok")
    
    #run ngrok
    system("/root/ngrok tcp -log=stdout 22 > /dev/null &")
    
    response = nil
    tunnel_url = nil
    sleep_until(10) {
      begin
        response = Net::HTTP.get_response(URI.parse("http://localhost:4040/api/tunnels"))
        if response.code.to_i == 200
          json_response = JSON.parse(response.body)
          if json_response["tunnels"].blank? || json_response["tunnels"][0].blank? || json_response["tunnels"][0]["public_url"].blank?
            false
          else
            tunnel_url = json_response["tunnels"][0]["public_url"]
            true
          end
        else
          false
        end 
      rescue  => e
        false
      end
    }
  
    if response == nil
      render json: {errors: "ngrok is not running: #{e}"}, status: 500
      return
    elsif tunnel_url.blank?
      render json: {errors: "ngrok api/tunnels returns error ()#{response.code}): #{response.body}"}, status: 500
      return
    end
    
    #post to cloud server
    begin
      uri = URI.parse("#{CLOUD_SERVER}/device/establish_support_tunnel")
      response = Net::HTTP.post_form(uri, 'serial' => Device.serial_number, 'url' => tunnel_url)
    rescue => e
      render json: {errors: "chai cloud server #{CLOUD_SERVER} cannot be reached: #{e}"}, status: 500
      return
    end
    
    if response.code.to_i != 200 
      render json: {errors: "publish tunnel url #{tunnel_url} failed (#{response.code}): #{response.body}"}, status: 500
      return
    end
    
    render :nothing=>true, :status=>:ok
  end
    
  api :GET, "/device/export_database", "export to exportdb.zip"
  def export_database
    config   = Rails.configuration.database_configuration
    dbfile = "/tmp/chaipcr.sql"
    system("mysqldump -u #{config[Rails.env]["username"]} #{(config[Rails.env]["password"])? "-p"+config[Rails.env]["password"] : ""} chaipcr > #{dbfile}")
    until File.exist?(dbfile)
      sleep 1
    end

    t = Tempfile.new("tmpexportdb.zip")
    logfiles = ["/var/log/realtime.log", "/var/log/realtime.log.1", "/var/log/syslog", "/var/log/syslog.1", "/var/log/daemon.log", "/var/log/daemon.log.1",
                "/var/log/dmesg", "/var/log/dmesg.0", "/var/log/life_age.log", "/var/log/rails.log", "/var/log/rails.log.1", "/var/log/unicorn.log", "/var/log/unicorn.log.1",
                "/sdcard/factory/booting.log", "/sdcard/upgrade/booting.log", "/var/log/upgrade.log"]
    configfiles = ["/root/configuration.json", "/perm/device.json"]
    begin
      Zip::OutputStream.open(t) { |zos| }

      Zip::File.open(t.path, Zip::File::CREATE) do |zipfile|
        zipfile.add("db/"+File.basename(dbfile), dbfile)
        [logfiles, configfiles].each do |files|
          folder = (files == logfiles)? "logs" : "config"
          files.each do |file_name|
            if File.exist?(file_name)
              basename  = File.basename(file_name)
              if basename == "booting.log"
                basename = File.dirname(file_name).split('/').last+"_"+basename
              end
              zipfile.add("#{folder}/"+basename, file_name)
            end
          end
        end
      end

      send_file t.path, :type => 'application/zip', :disposition => 'attachment', :filename => "exportdb.zip"
    ensure
      #Close and delete the temp file
      t.close
    end
  end
    
  private
  
  def erase_data
    start_time = Time.now
    User.delete_all
    logger.info "erase_data User.delete_all: Time elapsed #{(Time.now - start_time)*1000} milliseconds"
    start_time = Time.now
    Experiment.joins(:experiment_definition).where("experiment_type != ? and experiments.id != 1", ExperimentDefinition::TYPE_DIAGNOSTIC).select('experiments.*').each do |e|
      e.destroy
    end
    logger.info "erase_data experiments destroy: Time elapsed #{(Time.now - start_time)*1000} milliseconds"
    start_time = Time.now
    Setting.update_all("calibration_id=1")
    logger.info "erase_data settings update: Time elapsed #{(Time.now - start_time)*1000} milliseconds"
    start_time = Time.now
    if !Device.serial_number.blank?
      serialmd5 = Digest::MD5.hexdigest(Device.serial_number)
      system("printf '#{serialmd5}\n#{serialmd5}\n' | passwd")
    end
    logger.info "erase_data update password: Time elapsed #{(Time.now - start_time)*1000} milliseconds"
    start_time = Time.now
    system("sync")
    logger.info "erase_data sync: Time elapsed #{(Time.now - start_time)*1000} milliseconds"
  end
  
  def retrieve_mac
    str = `ifconfig eth0 | grep HWaddr`
  #  str = "eth0      Link encap:Ethernet  HWaddr 54:4a:16:c0:7e:38 "
    re = %r/([A-Fa-f0-9]{2}:){5}[A-Fa-f0-9]{2}/
    return re.match(str).to_s.strip
  end
  
  def allow_cors
    headers["Access-Control-Allow-Origin"] = "*"
    headers["Access-Control-Allow-Methods"] = "GET,PUT,POST,OPTIONS"
    headers["Access-Control-Allow-Headers"] = "*"
    headers["Access-Control-Max-Age"] = "1728000"
  end
  
  def sleep_until(time)
    time.times do
      break if block_given? && yield
      sleep(1)
    end
  end
  
end