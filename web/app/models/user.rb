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
class User < ActiveRecord::Base
  has_secure_password
  has_many :user_tokens
  
  validates :name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: /\A(|(([A-Za-z0-9]+_+)|([A-Za-z0-9]+\-+)|([A-Za-z0-9]+\.+)|([A-Za-z0-9]+\++))*[A-Za-z0-9]+@((\w+\-+)|(\w+\.))*\w{1,63}\.[a-zA-Z]{2,6})\z/i }
  validates :password, length:{minimum:4}, on: :create, if: '!password.blank?'
  
  ROLE_ADMIN    = "admin"
  ROLE_USER     = "user"

  before_create do |user|
    user.role = ROLE_USER if user.role.nil?
  end
        
  def self.empty?
    self.count == 0
  end
  
  def admin?
    self.role == ROLE_ADMIN
  end
  
  def role=(value)
    value = (!value.blank?)? value.strip.downcase : nil
    write_attribute(:role, value)
  end
  
  def email=(value)
    if !value.blank?
      write_attribute(:email, value.strip.downcase)
    end
  end
  
  def token
    if @user_token == nil
      @user_token = UserToken.create(:user=>self)
    end
    return (@user_token != nil)? @user_token.token : nil
  end
end