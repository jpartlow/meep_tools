#! /usr/bin/env ruby

TEST_PE_POSTGRESQL_ROOT_DIR=File.expand_path(File.join(File.dirname(__FILE__),'..'))
$LOAD_PATH << File.join(TEST_PE_POSTGRESQL_ROOT_DIR,'lib')
require 'run_shell'
require 'json'
require 'thor'
require 'diff_matcher'

class TestPostgresql < Thor
  class_option :vanagon_path
  class_option :debug, :type => :boolean, :default => false
  
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

  # Valid postgresql extension package patterns to build (need to be expanded with version)
  EXTENSIONS = [
    "pe-postgresql%s-pglogical",
    "pe-postgresql%s-pgrepack",
  ]

  # Valid pe-postgresql package versions
  VERSIONS = [
    "11",
    "10",
    "96",
  ].freeze

  def self.hosts_cache
    HOSTS_CACHE
  end

  def self.hosts_cache_file
    File.expand_path(self.hosts_cache)
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
    @io = stdout_io
    TestPostgresql.start(args)
  end

  include RunShellExecutable

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

  desc 'mount', 'Mount local $HOME/work/src into each of the vmpooler test hosts'
  def mount_nfs_hosts
    action('Create NFS mounts on hosts') do
      run("#{bolt} plan run meep_tools::nfs_mount -n #{hosts.values.join(',')}")
    end
  end

  desc 'getpe', 'Just download and unpack a PE tarball into /root. Either pe_family (for latest of that line) or pe_version must be specified.'
  method_option :pe_family, :type => :string
  method_option :pe_version, :type => :string
  def getpe
    action('Get a PE tarball onto the hosts and unpack it') do
      args = []
      args << "pe_family=#{options[:pe_family]}" if !options[:pe_family].nil?
      args << "pe_version=#{options[:pe_version]}" if !options[:pe_version].nil?
      raise(RuntimeError, "Must set either pe_family or pe_version.") if args.empty?
      run("#{bolt} plan run meep_tools::get_pe #{args.join(' ')} -n #{hosts.values.join(',')}")
    end
  end

  desc 'prep', 'Prep a PE install on the hosts with the -p option (download tarball, setup package repository, do not install)'
  method_option :pe_family, :type => :string, :required => true
  def prep
    action('Prep pe on the hosts') do
      run("#{bolt} plan run meep_tools::prep_pe pe_family=#{options[:pe_family]} -n #{hosts.values.join(',')}")
    end
  end

  desc 'build', 'Build pe-postgresql* packages for platforms, concurrently'
  method_option :platforms, :type => :array, :enum => PLATFORMS, :default => PLATFORMS
  method_option :packages, :type => :array, :enum => PACKAGES, :default => PACKAGES
  method_option :version, :type => :string, :enum => VERSIONS, :required => true
  def build
    action('Build pe-postgresql packages for a set of platforms (in parallel)') do
      package_names = construct_versioned_package_names
      _build_packages(options[:platforms], package_names)
    end
  end

  desc 'build_common', 'Build pe-postgresql-common package for platforms, concurrently'
  method_option :platforms, :type => :array, :enum => PLATFORMS, :default => PLATFORMS
  def build_common
    action('Build pe-postgresql-common package for a set of platforms (in parallel)') do
      _build_packages(options[:platforms], ['pe-postgresql-common'])
    end
  end

  desc 'build_extensions', 'Build the pe-postgresql*-{pglogical,pgrepack} extension package(s) for platforms, concurrently'
  method_option :platforms, :type => :array, :enum => PLATFORMS, :default => PLATFORMS
  method_option :packages, :type => :array, :enum => EXTENSIONS, :default => EXTENSIONS
  method_option :version, :type => :string, :enum => VERSIONS, :required => true
  def build_extensions
    action('Build pe-postgresql*-pglogical,pgrepack extension packages for a set of platforms (in parallel)') do
      package_names = construct_versioned_package_names
      _build_packages(options[:platforms], package_names)
    end
  end

  desc 'inject', 'Inject locally built pe-postgresql packages into the latest PE tarball of a given family that is present on the test nodes.'
  method_option :pe_family, :type => :string, :required => true
  method_option :postgres_version, :type => :string, :enum => VERSIONS, :required => true
  def inject
    action("Inject locally built pe-postgresql packages into latest PE #{options[:pe_family]} tarball on all test hosts.") do
      vanagon_output_dir = "#{get_vanagon_path}/output"
      run("#{bolt} plan run meep_tools::inject_packages pe_family=#{options[:pe_family]} postgres_version=#{options[:postgres_version]} output_dir=#{vanagon_output_dir} -n #{hosts.values.join(',')}")
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
        output = capture("#{bolt} task run meep_tools::get_package_file_lists packages='#{JSON.dump(package_names)}' -n #{hosts.values.join(',')} --format=json")
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
    # If the bolt gem is installed (via Bundler, for example), rbenv will have
    # added an ~/.rbenv/shims/bolt that will pick up the gem's version. And
    # since the shim also updates the path to prefix the current rbenv version shims,
    # the fact that my overrides in ~/bin are in the path gets pushed too far down to
    # be of use.
    #
    # So falling back to the absolute path of the package binary.
    def bolt
      "/opt/puppetlabs/bin/bolt"
    end

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

    def _package_build_thread(platform, package, vanagon_path)
      Thread.new do
        Thread.current[:platform] = platform
        Thread.current[:package] = package
        Thread.current[:level] = Thread.main[:level] || 0
        Thread.current[:success] = action("Starting: Build #{package} for #{platform}...") do
          run("bundle exec build #{package} #{platform}", :chdir => vanagon_path)
        end
      end
    end

    def get_vanagon_path
      vanagon_path = options[:vanagon_path] ? "#{options[:vanagon_path]}" : Dir.pwd
      if !vanagon_path.include?('puppet-enterprise-vanagon')
        out(red("Please specify the puppet-enterprise-vanagon path with the --vanagon-path flag, or run this command from inside the puppet-enterprise-vanagon directory"))
        raise(ArgumentError, "#{vanagon_path} does not seem to point to a puppet-enterprise-vanagon checkout")
      end
      return vanagon_path
    end

    def _build_packages(platforms, package_names)
      vanagon_path = get_vanagon_path
      threads = platforms.product(package_names).map do |i|
        platform, package = i
        _package_build_thread(platform, package, vanagon_path)
      end
      threads.each do |t|
        t.join
        out("Finished: Build #{t[:package]} for #{t[:platform]}")
      end
      threads.all? { |t| t[:success] }
    end
  end
end

# Execute if the script is called on the command line.
if $0 == __FILE__
  TestPostgresql.invoke(ARGV)
  #exit(result)
end
