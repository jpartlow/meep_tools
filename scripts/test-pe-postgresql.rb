#! /usr/bin/env ruby

TEST_PE_POSTGRESQL_ROOT_DIR=File.expand_path(File.join(File.dirname(__FILE__),'..'))
$LOAD_PATH << File.join(TEST_PE_POSTGRESQL_ROOT_DIR,'lib')
require 'run_shell'
require 'meep_tools/threaded'
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

  # Valid PE installation layouts
  LAYOUTS = [
    'mono',
    'master_database',
  ].freeze

  # VMs needed per layout
  LAYOUT_VM_COUNTS = {
    'mono'            => 1,
    'master_database' => 2,
  }.freeze

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

  def self.pe_builds_dir
    "#{ENV['HOME']}/pe_builds"
  end

  def self.invoke(args, stdout_io = nil)
    config = {}
    config[:_runshell_stdout_io] = stdout_io if !stdout_io.nil?
    TestPostgresql.start(args, config)
  end

  def initialize(args = [], opts = [], config = {})
    # Reset output io if we were invoked with a different io instance
    # (typically for testing)
    self.io = config.delete(:_runshell_stdout_io) if config.include?(:_runshell_stdout_io)
    super(args, opts, config)
  end

  include RunShellExecutable
  include MeepTools::Threaded

  desc 'create', 'Generate one or more vmpooler test hosts, if they do not already exist'
  method_option :platforms, :type => :array, :default => PLATFORMS
  method_option :count, :type => :numeric, :default => 1
  def create_hosts
    validate_enum(:platforms, PLATFORMS)
    _create_hosts(options[:platforms], options[:count])
  end

  desc 'delete', 'Ensure all vmpooler hosts referenced in the cache are released'
  def delete_hosts
    action('Delete hosts') do
      run("floaty delete #{all_hosts.join(',')}")
    end
  end

  desc 'mount', 'Mount local $HOME/work/src into each of the vmpooler test hosts'
  def mount_nfs_hosts
    action('Create NFS mounts on hosts') do
      run("#{bolt} plan run meep_tools::nfs_mount -n #{all_hosts.join(',')}")
    end
  end

  desc 'getpe', 'Just download and unpack a PE tarball into /root. Either pe_family (for latest of that line) or pe_version must be specified.'
  method_option :pe_family, :type => :string
  method_option :pe_version, :type => :string
  def getpe
    action('Get a PE tarball onto the hosts and unpack it') do
      args = pe_family_or_version(options)
      raise(RuntimeError, "Must set either --pe-family or --pe-version.") if args.empty?
      run("#{bolt} plan run enterprise_tasks::testing::get_pe #{args.join(' ')} -n #{all_hosts.join(',')}")
    end
  end

  desc 'peconf', 'Write out a pe.conf on the nodes, setting puppet_master_host and postgres_version_override if given'
  method_option :postgres_version, :type => :string, :enum => VERSIONS
  def peconf
    action('Write a /root/pe.conf') do
      other_parameters = case
      when options.include?(:postgres_version) then
        pg_version = options[:postgres_version] == '96' ? '9.6' : options[:postgres_version]
        %Q{other_parameters='{"puppet_enterprise::postgres_version_override":"#{pg_version}"}'}
      else ''
      end
      all_hosts.each do |host|
        action("on #{host}") do
          run(%Q|#{bolt} plan run enterprise_tasks::testing::create_pe_conf master=#{host} console_admin_password=password #{other_parameters} -n #{host}|)
        end
      end
    end
  end

  desc 'install', 'Install PE from a tarball already present on the hosts'
  method_option :pe_version, :type => :string
  method_option :debug_logging, :type => :boolean, :default => false
  def install
    action("Install PE on hosts based on #{args.join(' ')}") do
      run(%Q|#{bolt} task run enterprise_tasks::testing::run_installer version=#{pe_version} debug_logging=#{options[:debug_logging]} -n #{all_hosts.join(',')}|)
    end
  end

  desc 'upgrade', 'Upgrade PE from a tarball already present on the hosts'
  method_option :pe_version, :type => :string
  method_option :debug_logging, :type => :boolean, :default => false
  method_option :non_interactive, :type => :boolean, :default => true
  def upgrade
    action("Upgrade PE on hosts based on #{args.join(' ')}") do
      run(%Q|#{bolt} task run enterprise_tasks::testing::run_installer version=#{pe_version} non_interactive=#{options[:non_interactive]} debug_logging=#{options[:debug_logging]} -n #{all_hosts.join(',')}|)
    end
  end

  desc 'frankenbuild', 'Generate frankenbuild tarballs for each platform with the given puppet-enterprise-modules patch, concurrently'
  method_option :platforms, :type => :array, :default => PLATFORMS
  method_option :pem_pr, :type => :numeric
  method_option :pe_family, :type => :string
  def frankenbuild
    validate_enum(:platforms, PLATFORMS)
    action("Frankenbuild tarballs with p-e-m pr##{options[:pem_pr]}") do
      run_threaded_product('Frankenbuild', platform: options[:platforms]) do |variant|
        run(%Q|#{bolt} plan run meep_tools::frankenbuild_tarball platform=#{variant[:platform]} pe_family=#{options[:pe_family]} pem_pr=#{options[:pem_pr]} pe_builds_dir=#{pe_builds_dir}|)
      end
    end
  end

  desc 'test_migration', 'Test a database migration from a given PE version to another version or local tarball'
  method_option(
    :install_versions,
    :type => :array,
    :desc => "The initial version to install. May be a space separated list if you want to test upgrades from different versions."
  )
  method_option(
    :upgrade_version,
    :type => :string,
    :desc => "A specific version to upgrade to."
  )
  method_option(
    :upgrade_tarball_version,
    :type => :string,
    :desc => "Alternately, the build version of a local frankenbuild stashed in #{TestPostgresql.pe_builds_dir} by the frankenbuild action."
  )
  method_option(
    :layouts,
    :type => :array,
    :default => ['mono'],
    :desc => "The PE layout, or a space separated list of PE layouts, to test."
  )
  method_option(
    :create_vms,
    :type => :boolean,
    :default => false,
    :desc => "Generate/validate existence of an array of vms required to complete the testing."
  )
  def test_migration
    validate_enum(:layouts, LAYOUTS)
    action('Test migration') do
      platforms = hosts.keys
      install_versions = options[:install_versions]
      version_variations = install_versions.size
      layouts = options[:layouts]
      create_vms = options[:create_vms]

      # Count required vms per platform
      layout_vms = layouts.sum { |l| LAYOUT_VM_COUNTS[l] }
      vms_needed_per_platform = version_variations * layout_vms
      out(grey("We will need #{vms_needed_per_platform} vms per platform to cover #{version_variations} install versions for #{layouts} layouts"))

      if create_vms
        _create_hosts(platforms, vms_needed_per_platform)
      elsif hosts.values.first.size < vms_needed_per_platform
        raise(RuntimeError, "Need #{vms_needed_per_platform} vms per platform. #{hosts.keys.first} only has #{hosts.values.first.size} listed. Run with --create-vms?")
      end

      available_hosts = hosts.dup.transform_values { |v| v.dup }

      run_threaded_product('Migration test', platform: platforms, installed: install_versions, layout: layouts, _split_output: true) do |variant|

        platform = variant[:platform]
        install_version = variant[:installed]
        layout = variant[:layout]
        assigned_hosts = available_hosts[platform].pop(LAYOUT_VM_COUNTS[layout])

        command = ["#{bolt} plan run enterprise_tasks::testing::upgrade_workflow"]
        command << "nodes=#{assigned_hosts.join(',')}"
        command << "upgrade_from=#{install_version}"
        command << "upgrade_to_version=#{options[:upgrade_version]}" if options.include?('upgrade_version')
        command << "upgrade_to_tarball='#{pe_builds_dir}/puppet-enterprise-#{options[:upgrade_tarball_version]}-#{platform}.tar.gz'" if options.include?('upgrade_tarball_version')
        command << %Q{update_pe_conf='{"puppet_enterprise::postgres_version_override":"11"}'}
        command << "--debug" if debugging?
        run(command.join(' '))
      end
    end
  end

  desc 'uninstall_pe', 'Run the puppet-enterprise-uninstaller script on each node to wipe away PE'
  def uninstall_pe
    action('Uninstall PE') do
      run("#{bolt} command run '/opt/puppetlabs/bin/puppet-enterprise-uninstaller -ydp' -n #{all_hosts.join(',')}", debugging: true)
    end
  end

  desc 'prep', 'Prep a PE install on the hosts with the -p option (download tarball, setup package repository, do not install)'
  method_option :pe_family, :type => :string, :required => true
  def prep
    action('Prep pe on the hosts') do
      run("#{bolt} plan run meep_tools::prep_pe pe_family=#{options[:pe_family]} -n #{all_hosts.join(',')}")
    end
  end

  desc 'build', 'Build pe-postgresql* packages for platforms, concurrently'
  method_option :platforms, :type => :array, :default => PLATFORMS
  method_option :packages, :type => :array, :default => PACKAGES
  method_option :version, :type => :string, :enum => VERSIONS, :required => true
  def build
    validate_enum(:platforms, PLATFORMS)
    validate_enum(:packages, PACKAGES)
    action('Build pe-postgresql packages for a set of platforms (in parallel)') do
      package_names = construct_versioned_package_names
      _build_packages(options[:platforms], package_names)
    end
  end

  desc 'build_common', 'Build pe-postgresql-common package for platforms, concurrently'
  method_option :platforms, :type => :array, :default => PLATFORMS
  def build_common
    validate_enum(:platforms, PLATFORMS)
    action('Build pe-postgresql-common package for a set of platforms (in parallel)') do
      _build_packages(options[:platforms], ['pe-postgresql-common'])
    end
  end

  desc 'build_extensions', 'Build the pe-postgresql*-{pglogical,pgrepack} extension package(s) for platforms, concurrently'
  method_option :platforms, :type => :array, :default => PLATFORMS
  method_option :packages, :type => :array, :default => EXTENSIONS
  method_option :version, :type => :string, :enum => VERSIONS, :required => true
  def build_extensions
    validate_enum(:platforms, PLATFORMS)
    validate_enum(:packages, EXTENSIONS)
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
      package_names = construct_versioned_package_names
      run("#{bolt} plan run meep_tools::inject_packages pe_family=#{options[:pe_family]} package_names='#{JSON.dump(package_names)}' output_dir=#{vanagon_output_dir} -n #{all_hosts.join(',')}")
    end
  end

  desc 'compare_packages', 'Compare contents of pe-postgresql* packages for all platforms'
  method_option :packages, :type => :array, :default => PACKAGES
  method_option :version, :type => :string, :enum => VERSIONS, :required => true
  def compare_packages
    validate_enum(:packages, PACKAGES)
    action('Compare pe-postgresql* package file lists for discrepancies') do
      package_names = construct_versioned_package_names
      nodes = []

      action('Get package file lists') do
        output = capture("#{bolt} task run meep_tools::get_package_file_lists packages='#{JSON.dump(package_names)}' -n #{all_hosts.join(',')} --format=json")
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

    # Location of local PE tarballs.
    def pe_builds_dir
      TestPostgresql.pe_builds_dir
    end

    def debugging?
      # Thor class_option :debug
      options[:debug]
    end

    def all_successful(&block)
      results = []
      yield results
      results.all? { |s| s == true }
    end

    def hosts
      @hosts ||= TestPostgresql.read_hosts_cache
    end

    # @return [Array] collects all the hosts into a single array regardless of platform.
    def all_hosts
      hosts.values.flatten
    end

    def hosts=(hosts_cache)
      @hosts = hosts_cache
    end

    # @return [Array<String>] an array of the pe_family and/or pe_version args,
    #   if given, suitable for passing to bolt.
    def pe_family_or_version(opts)
      args = []
      args = "version=#{opts[:pe_family]}" if !opts[:pe_family].nil?
      # pe_version, being more specific, takes precedence
      args = "version=#{opts[:pe_version]}" if !opts[:pe_version].nil?
      args
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

    def create_hosts_for(platform, count, adding: false)
      floaty_platform = translate_platform_for_vmfloaty(platform)
      # It's possible we could have a case of only some hosts active, but
      # it is more likely that all the cached refs are yesterdays and have
      # been reaped. So we just replace the array unless we're specifically
      # adding to it.
      hosts[platform] = [] unless adding
      results = count.times.map do
        if out = capture("floaty get #{floaty_platform}")
          # capturing something like:
          # '- ves8qa9rzwbp4rv.delivery.puppetlabs.net (redhat-7-x86_64)'
          host = out.split(' ')[1]
          hosts[platform] << host
          true
        else
          false
        end
      end
      results.all?
    end

    def _create_hosts(platforms, count)
      action('Verify or create hosts') do
        active_host_list = capture("floaty list --active")
        all_successful do |results|
          platforms.each do |p|
            host_array = Array(hosts[p])
            hosts_live = live?(host_array, active_host_list)
            hosts_sufficient = host_array.size >= count
            results << case
            when hosts_live && hosts_sufficient then true
            when hosts_live then create_hosts_for(p, count - host_array.size, adding: true)
            else create_hosts_for(p, count)
            end
          end
          write_hosts_cache
          out("Created hosts:\n#{hosts.pretty_inspect}")
        end
      end
    end

    def live?(host_array, active_host_list)
      !host_array.empty? && host_array.all? do |host|
        host.nil? ?
          false :
          !active_host_list.match(/#{host}/).nil?
      end
    end

    def write_hosts_cache(hosts_cache_path = TestPostgresql.hosts_cache_file)
      TestPostgresql.write_hosts_cache(hosts, hosts_cache_path)
    end

    def construct_versioned_package_names
      options[:packages].map { |p| p % options[:version] }
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
      run_threaded_product('Build', platform: platforms, package: package_names) do |variants|
        run("bundle exec build #{variants[:package]} #{variants[:platform]}", :chdir => vanagon_path)
      end
    end

    # Thor does not check :type => array's elements against :enum, unlike :string or :numeric...
    def validate_enum(option, enum)
      values = options[option]
      values.all? { |a| enum.include?(a) } || raise(ArgumentError, "The --#{option} argument must consist of one or more space separated values from #{enum}. Got: #{values}")
    end
  end
end

# Execute if the script is called on the command line.
if $0 == __FILE__
  TestPostgresql.invoke(ARGV)
end
