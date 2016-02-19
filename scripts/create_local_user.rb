#! /usr/bin/env ruby
require 'scooter'
require 'beaker'
include Scooter::HttpDispatchers

class PEUser

  attr_accessor :console, :console_hostname, :platform, :user_name, :password
  attr_reader :body

  def initialize(console_hostname, platform, user_name, password)
    self.console_hostname = console_hostname
    self.platform = Beaker::Platform.new(platform)
    self.console = Beaker::Host.create(
      console_hostname, 
      { 
        :logger => Beaker::Logger.new,
        :platform => self.platform,
        :ssh => {
          "config" => false,
          "paranoid" => false,
          "auth_methods" => [
              "publickey"
          ],
          "port" => 22,
          "forward_agent" => true,
          "keys" => [
              "~/.ssh/id_rsa-acceptance"
          ],
          "user_known_hosts_file" => "~/.ssh/known_hosts",
        },
      },
      {})
    self.user_name = user_name
    self.password = password 
  end

  def dispatcher
    @dispatcher ||= ConsoleDispatcher.new(console)
  end
  
  def generate_user
    existing_admin = dispatcher.get_current_user_data
    @body = dispatcher.create_local_user({
      "login" => user_name,  
      "email" => "#{user_name}@example.com",
      "display_name" => "Test user #{user_name}",
      "role_ids" => existing_admin['role_ids'],
      "password" => password
      }).body
  end

  def remove_user
    dispatcher.delete_local_user(dispatcher.get_user_id_by_login_name(user_name))
  end
end

def usage
  puts "Usage: create_local_user <console-hostname.delivery.puppetlabs.net> <create|remove> [el-7-x86_64] [auser] [password]"
  exit 1
end

console_hostname = ARGV[0]
command   = ARGV[1]
platform  = ARGV[2] || 'el-7-x86_64'
user_name = ARGV[3] || 'auser'
password  = ARGV[4] || 'password'

unless console_hostname
  usage
end

pe_user = PEUser.new(console_hostname, platform, user_name, password)

case command
  when 'create' then pe_user.generate_user
  when 'remove' then pe_user.remove_user
  else usage
end
