#! /usr/bin/env ruby

TEST_PE_POSTGRESQL_ROOT_DIR=File.expand_path(File.join(File.dirname(__FILE__),'..'))
$LOAD_PATH << File.join(TEST_PE_POSTGRESQL_ROOT_DIR,'lib')
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

  # Valid package patterns to build (need to be expanded with version)
  PACKAGES = [
    "pe-postgresql%s",
    "pe-postgresql%s-server",
    "pe-postgresql%s-contrib",
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

  class_option :debug, :type => :boolean, :default => false

  desc 'create', 'Generate one or more vmpooler test hosts, if they do not already exist'
  method_option :platforms, :type => :array, :enum => PLATFORMS, :default => PLATFORMS
  def create_hosts
    action('Verify or create hosts') do
      all_successful do |results|
        options[:platforms].each do |p|
          host = hosts[p]
          results << (live?(host) ?
            true :
            create_host_for(p)
          )
        end
        write_hosts_cache
      end
    end
  end

  desc 'mount', 'Mount local $HOME/work/src into each of the fmpooler test hosts'
  def mount_nfs_hosts
    action('Create NFS mounts on hosts') do
      run("bolt plan run integration::nfs_mount -n #{hosts.values.join(',')}", :chdir => TEST_PE_POSTGRESQL_ROOT_DIR)
    end
  end

  desc 'prep', 'Prep a PE install on the hosts with the -p option (download tarball, setup package repository, do not install)'
  method_option :pe_family, :type => :string, :required => true
  def prep
    action('Prep pe on the hosts') do
      run("bolt plan run integration::prep_pe pe_family=#{options[:pe_family]} -n #{hosts.values.join(',')}", :chdir => TEST_PE_POSTGRESQL_ROOT_DIR)
    end
  end

  desc 'build', 'Build pe-postgresql* packages for platforms, concurrently'
  method_option :platforms, :type => :array, :enum => PLATFORMS, :default => PLATFORMS
  method_option :packages, :type => :array, :enum => PACKAGES, :default => PACKAGES
  method_option :version, :type => :string, :enum => VERSIONS, :required => true
  def build
    action('Build pe-postgresql packages for a set of platforms (in parallel)') do
      package_names = options[:packages].map { |p| p % options[:version] }
      threads = options[:platforms].product(package_names).map do |i|
        platform, package = i
        Thread.new do
          Thread.current[:platform] = platform
          Thread.current[:package] = package
          Thread.current[:level] = Thread.main[:level] || 0
          action("Starting: Build #{package} for #{platform}...") do
            run("bundle exec build #{package} #{platform}", :chdir => '/s/puppet-enterprise-vanagon')
          end
        end
      end
      threads.each do |t|
        t.join
        out("Finished: Build #{t[:package]} for #{t[:platform]}")
      end
    end
  end

  no_commands do
    def debugging?
      # Thor class_option :debug
      options[:debug]
    end

    def io
      TestPostgresql.io
    end

    def all_successful(&block)
      results = []
      yield results
      results.all? { |s| s == true }
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
