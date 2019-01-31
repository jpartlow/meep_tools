#! /usr/bin/env ruby

TEST_PE_POSTGRESQL_ROOT_DIR=File.expand_path(File.join(File.dirname(__FILE__),'..'))
$LOAD_PATH << File.join(TEST_PE_POSTGRESQL_ROOT_DIR,'lib')
require 'run_shell'
require 'json'
require 'thor'
require 'diff_matcher'

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
    "pe-postgresql%s-devel",
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
      package_names = construct_versioned_package_names
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

  desc 'compare_packages', 'Compare contents of pe-postgresql* packages for all platforms'
  method_option :packages, :type => :array, :enum => PACKAGES, :default => PACKAGES
  method_option :version, :type => :string, :enum => VERSIONS, :required => true
  def compare_packages
    action('Compare pe-postgresql* package file lists for discrepancies') do
      package_names = construct_versioned_package_names
      nodes = []

      action('Get package file lists') do
        output = capture("bolt task run integration::get_package_file_lists packages='#{JSON.dump(package_names)}' -n #{hosts.values.join(',')} --format=json", :chdir => TEST_PE_POSTGRESQL_ROOT_DIR)
        output = JSON.parse(output)
        nodes = output["items"]
      end

      action('Find overlaps of packages for a given node platform') do
        overlaps = {}

        nodes.each do |node|
          platform   = node["result"]["platform"]
          file_lists = node["result"]["files"]
          node_name  = node["node"]
          node_key   = "#{platform}_#{node_name}"

          action("Evaluating #{node_key}:") do
            overlaps[node_key] = {}

            package_names.each do |package|
              action("Package #{package}:") do
                other_packages = package_names - [package]
                other_packages.each do |other|
                  overlap = file_lists[package] & file_lists[other]
                  overlaps[node_key][package] = overlap
                  if overlap.empty?
                    out(green("Has no overlap with #{other}"))
                  else
                    out(red("Overlaps #{other}:"))
                    out(overlap.pretty_inspect)
                  end
                end
              end
            end
          end

          action('Looking for mismatched binary files') do
            binaries = package_names.reduce({}) do |hash,p|
              hash[p] = file_lists[p].grep(%r{/opt/puppetlabs/server/apps/postgresql/[\d.]+/bin/})
              hash
            end

            binaries.each do |package,bin_paths|
              action("from #{package}") do
                package_names.each do |other_package|
                  next if package == other_package
                  action("in #{other_package}") do
                    bin_paths.each do |full_path|
                      bin = full_path.split('/').last
                      refs = file_lists[other_package].grep(%r{/#{bin}(?:[^/]*)$})
                      if refs.empty?
                        out(grey("no references to #{bin} found"))
                      else
                        out(red("found #{bin}:"))
                        out(refs.pretty_inspect, :bump_level => 1)
                      end
                    end
                  end
                end
              end
            end
          end
        end

        action('Looking for differences in overlaps between platforms') do
          if overlaps.values.uniq.length == 1
            out('no platform differences')
          else
            index = overlaps.keys.first
            other_platforms = overlaps.keys - [index]
            other_platforms.each do |other|
              action("Diffing #{index} with #{other}") do
                diff = DiffMatcher.difference(overlaps[index], overlaps[other], :color_scheme => :black_background)
                if diff.nil?
                  out(green('no difference'))
                else
                  out(diff)
                end
              end
            end
          end
        end
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

    def construct_versioned_package_names
      options[:packages].map { |p| p % options[:version] }
    end
  end
end

# Execute if the script is called on the command line.
if $0 == __FILE__
  TestPostgresql.invoke(ARGV)
  #exit(result)
end
