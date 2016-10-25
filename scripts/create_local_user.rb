#! /opt/puppetlabs/puppet/bin/ruby
require 'net/http'
require 'openssl'
require 'json'

class PEUser

  attr_accessor :console, :console_hostname, :user_name, :password
  attr_reader :body

  def initialize(console_hostname, user_name, password)
    self.console_hostname = console_hostname
    self.user_name = user_name
    self.password = password 
  end

  def dispatcher
    if @dispatcher.nil?
      fqdn = (`facter fqdn`).strip
      @dispatcher = Net::HTTP.new(console_hostname, 4433)
      @dispatcher.use_ssl = true
      ca_cert_path = '/etc/puppetlabs/puppet/ssl/certs/ca.pem'
      cert_path = "/etc/puppetlabs/puppet/ssl/certs/#{fqdn}.pem"
      key_path = "/etc/puppetlabs/puppet/ssl/private_keys/#{fqdn}.pem"
      @dispatcher.ca_file = ca_cert_path
      @dispatcher.verify_mode = OpenSSL::SSL::VERIFY_PEER
      @dispatcher.cert = OpenSSL::X509::Certificate.new(File.read(cert_path))
      @dispatcher.key  = OpenSSL::PKey::RSA.new(File.read(key_path), nil)
#      @dispatcher.set_debug_output($stderr)
    end
    @dispatcher
  end

  def get_admin_user
    response = dispatcher.get('/rbac-api/v1/users/current')
    raise(RuntimeError, response) unless response.code == '200'
    JSON.parse(response.body)
  end

  def get_users
    response = dispatcher.get('/rbac-api/v1/users')
    raise(RuntimeError, response) unless response.code == '200'
    JSON.parse(response.body)
  end

  def generate_user
    existing_admin = get_admin_user
    user_hash = {
      "login" => user_name,  
      "email" => "#{user_name}@example.com",
      "display_name" => "Test user #{user_name}",
      "role_ids" => existing_admin['role_ids'],
      "password" => password
    }
    response = dispatcher.post('/rbac-api/v1/users', user_hash.to_json, {"Content-Type" => "application/json"})
    raise(RuntimeError, response) unless response.code == '303'
    puts get_users 
  end

  def remove_user
    id = get_users.find { |u| u['login'] == user_name }['id']
    response = dispatcher.delete("/rbac-api/v1/users/#{id}")
    raise(RuntimeError, response) unless response.code == '204'
    puts get_users
  end
end

def usage
  puts "Usage: create_local_user <console-hostname.delivery.puppetlabs.net> <create|remove> [auser] [password]"
  exit 1
end

console_hostname = ARGV[0]
command    = ARGV[1]
user_name  = ARGV[2] || 'auser'
password   = ARGV[3] || 'password'

unless console_hostname
  usage
end

pe_user = PEUser.new(console_hostname, user_name, password)

case command
  when 'create' then pe_user.generate_user
  when 'remove' then pe_user.remove_user
  else usage
end
