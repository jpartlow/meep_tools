#! /usr/bin/env ruby

$LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__),'..','lib'))
require 'run_shell'
require 'json'
require 'thor'

class TestPostgresql < Thor
  # Hosts cache keeps track of generated vmpooler hosts.
  HOSTS_CACHE = "~/.test-pe-postgresql.json"

  # Valid master platforms
  PLATFORMS = [
    "el-7-x86_64",
    "el-6-x86_64",
    "ubuntu-16.04-amd64",
    "ubuntu-18.04-amd64",
    "sles-12-x86_64",
  ].freeze

  # Valid pe-postgresql package versions
  VERSIONS = [
    "10",
    "96",
  ].freeze

  def self.hosts_cache_file
    File.expand_path(HOSTS_CACHE)
  end

  def self.read_hosts_cache(hosts_cache_path = self.hosts_cache_file)
    hosts = {}
    if !hosts_cache_path.nil? && !hosts_cache_path.empty? &&
       File.exist?(hosts_cache_path)

      file = File.new(hosts_cache_path)
      hosts = JSON.load(file)
    end
    hosts
  end

  def self.write_hosts_cache(hosts, hosts_cache_path = self.hosts_cache_file)
    json = JSON.pretty_generate(hosts)
    File.write(hosts_cache_path, "#{json}\n")
    return true
  end

  def self.io
    @io
  end

  def self.io=(io)
    @io = io
  end

  def self.invoke(args, stdout_io = $stdout)
    @io = $stdout
    TestPostgresql.start(args)
  end

  include RunShellExecutable

  desc 'create', 'Generate one or more vmpooler test hosts, if they do not already exist'
  method_option :platforms, :type => :array, :enum => PLATFORMS, :default => PLATFORMS
  def create_hosts
    action('Verify or create hosts') do
      successful = []
      options[:platforms].each do |p|
        host = hosts[p]
        successful << (live?(host) ?
          true :
          create_host_for(p)
        )
      end
      write_hosts_cache
      successful.all? { |s| s == true }
    end
  end

  no_commands do
    def io
      TestPostgresql.io
    end

    def hosts
      @hosts ||= TestPostgresql.read_hosts_cache
    end

    def hosts=(hosts_cache)
      @hosts = hosts_cache
    end

    # Convert from platform strings vanagon will recognize to ones vmfloaty
    # will recognize.
    def translate_platform_for_vmfloaty(platform)
      case platform
      when /^el-(.*)/ then "centos-#{$1}"
      when /^ubuntu-(.*)-/ then "ubuntu-#{$1.gsub('.','')}-x86_64"
      else platform
      end
    end

    def create_host_for(platform)
      floaty_platform = translate_platform_for_vmfloaty(platform)
      if out = capture("floaty get #{floaty_platform}")
        # capturing something like:
        # '- ves8qa9rzwbp4rv.delivery.puppetlabs.net (redhat-7-x86_64)'
        host = out.split(' ')[1]
        hosts[platform] = host
        true
      else
        false
      end
    end

    def live?(host)
      host.nil? ?
        false :
        test("floaty list --active | grep #{host}")
    end

    def write_hosts_cache(hosts_cache_path = TestPostgresql.hosts_cache_file)
      TestPostgresql.write_hosts_cache(hosts, hosts_cache_path)
    end
  end
end

# Execute if the script is called on the command line.
if $0 == __FILE__
  TestPostgresql.invoke(ARGV)
  #exit(result)
end
