require 'optparse'
require 'fog/openstack'
require 'pp'

module OSC

  # Raised if an option such as --help or --version cuts short execution.
  class EndOfOperation < SystemExit; end

  class OSCError < RuntimeError; end

  # Raised if unable to locate a specified beaker hosts file.
  class NoHostsFile < OSCError; end

  # Raised if unable to lookup a given flavor or image name for an OpenStack
  # Server
  class UnknownServerAttribute < OSCError; end

  # Raised if unable to lookup a specific host by name.
  class UnknownHost < OSCError; end

  # All of these assume that necessary configuration has been
  # placed in ~/.fog where fog-openstack will look up settings.
  module FogOpenStackHandles
    attr_writer :compute

    def compute
      unless @compute
        @compute = ::Fog::Compute::OpenStack.new({})
      end
      @compute
    end
  end

  # drop pod meep2
  # create pod meep2
  # list pods
  class OpenStackControl
    VERSION = '0.0.1'

    include FogOpenStackHandles

    # Default host definitions are in the beaker/ subdir of this repository.
    DEFAULT_BEAKER_HOSTS_PATH = File.expand_path(File.join(File.dirname(__FILE__),'..','..','beaker'))

    # IO object for output; defaults to STDOUT, may be set to something
    # else for testing.
    attr_accessor :out
    # Integer set to indicate success or failure for the command line.
    attr_accessor :exit_code
    # Path to Beaker host files. Each file is presumed to define a pod
    # of servers, with correct openstack attributes so that we can create,
    # list, drop a given server set as needed
    attr_accessor :beaker_hosts_path
    attr_accessor :args, :command, :options, :parser

    def self.process(args, out = STDOUT)
      osc = case args.first
      when 'create'
        OSC::Create.new(args, out)
      when 'drop'
        OSC::Drop.new(args, out)
      when 'list'
        OSC::List.new(args, out)
      when 'show'
        OSC::Show.new(args, out)
      else
        new(args, out)
      end

      osc.parse_options ?
        osc :
        OSC::Noop.new(osc.exit_code)
    end

    def initialize(args, out = STDOUT)
      self.args = args
      self.out = out
      self.exit_code = 0
      self.beaker_hosts_path = DEFAULT_BEAKER_HOSTS_PATH
    end

    ###########################
    # fog/openstack methods

    def lookup_image(name)
      _lookup!(:images, name)
    end

    def lookup_flavor(name)
      _lookup!(:flavors, name)
    end

    def lookup_security_group(name)
      _lookup!(:security_groups, name)
    end

    def create_server(attrs)
      flavor_name = attrs.delete('flavor')
      flavor = lookup_flavor(flavor_name)

      image_name = attrs.delete('image')
      image = lookup_image(image_name)

      key_name = attrs.delete('openstack_keyname')

      # Note, beaker-openstack is expecting 'security_group', which an be
      # an array. fog-openstack expects 'security_groups'...
      security_groups = attrs.delete('security_group')
      security_groups.map! { |sg| lookup_security_group(sg) } if security_groups

      dereferenced_attrs = attrs.merge({
        'flavor_ref' => flavor.id,
        'image_ref'  => image.id,
        'key_name'   => key_name,
      })
      dereferenced_attrs.merge!(
        'security_groups' => security_groups
      ) if security_groups

      compute.servers.create(dereferenced_attrs)
    end

    def drop_server(name)
      server = get_server(name)
      if server
        server.destroy
      else
        false
      end
    end

    def get_server(name)
      _lookup(:servers, name)
    end

    def server_list(pod = nil)
      servers = compute.servers
      if !pod.nil?
        hostnames = get_pod_hosts(pod).map { |h| h['name'] }
        servers.select! { |s| hostnames.include?(s.name) }
      end
      servers
    end

    # Return a list of available floating ip addreses in descending
    # order.
    #
    #  '10.32.160.104'
    #  '10.32.160.20'
    #  '10.32.160.19'
    #  '10.32.160.18'
    #  '10.32.149.101'
    #
    # The sorting is purely a convenience for keeping some human meaningful
    # predictability in ips we assign to a particular pod.
    def openstack_floatingips
      ips = openstack_get_json('floating', 'ip', 'list')
      ips.reject! do |i|
        !i['Fixed IP Address'].nil?
      end
      ips.map! do |i|
        i['Floating IP Address']
      end
      ips.sort do |a,b|
        ip1 = a.split('.').map { |ip| ip.to_i }
        ip2 = b.split('.').map { |ip| ip.to_i }

        ip1.zip(ip2).reduce(0) do |cmp,ip|
          c = ip[0] <=> ip[1]
          if c == 0
            c
          else
            # the first element to differ short circuits the remainder
            break c
          end
        end
      end.reverse
    end

    # end fog/openstack methods
    ###########################

    ##########################
    # Beaker hosts methods

    # Lookup a Beaker hosts config named "#{pod}.hosts" or "#{pod}.yaml" from
    # our #beaker_hosts_path and return a hash of the defined HOSTS each with
    # CONFIG mixed in.
    #
    # @param pod [String] name of the hosts config (without extension).
    # @return [Array<Hash>] return an array of host attribute hashes.
    def get_pod_hosts(pod)
      hosts_files = [
        "#{beaker_hosts_path}/#{pod}.hosts",
        "#{beaker_hosts_path}/#{pod}.yaml",
      ]

      yaml = {}
      hosts_files.each do |file|
        if File.exist?(file)
          yaml = YAML.load_file(file)
          break
        end
      end

      raise(OSC::NoHostsFile, "Could not find any beaker hosts files matching #{beaker_hosts_path}/#{pod}.{hosts,yaml}.") if yaml.empty?

      yaml['HOSTS'].map do |name,attrs|
        attrs['name'] = name
        yaml['CONFIG'].merge(attrs)
      end
    end

    # end Beaker hosts methods
    ##########################

    ######################
    # optparse methods

    def parse_options
      self.parser = OptionParser.new
      _banner(parser)
      _subcommand(parser)
      _common(parser)

      self.command = parser.parse(args)
      return true

    rescue OptionParser::InvalidOption => e
      out.puts e.message
      out.puts parser
      self.exit_code = 1
      return false
    rescue EndOfOperation => e
      self.exit_code = e.status
      return false
    end

    def _banner(parser)
      parser.banner = "Usage: oscontrol <subcommand> [options]"
      parser.separator ""
    end

    def _subcommand(parser)
      parser.separator "Subcommands:"
      parser.separator ""
      parser.separator "  list [pod]"
      parser.separator "  create <pod>"
      parser.separator "  drop <pod>"
      parser.separator "  show <host>"
      parser.separator ""
    end

    def _common(parser)
      parser.separator "Common options:"

      description = [
        "Path to a directory containing Beaker hosts yaml files. Each file",
        "defines a set of servers that we can operate on in openstack with",
        "this tool. Defaults to #{DEFAULT_BEAKER_HOSTS_PATH}.",
      ]
      parser.on("--beaker-hosts-path=PATH", description.join(' ')) do |opt|
        self.beaker_hosts_path = opt
      end

      parser.on_tail("-h", "--help", "Show this message") do
        out.puts parser
        raise(EndOfOperation, 0)
      end

      parser.on_tail("--version", "Show version") do
        out.puts VERSION
        raise(EndOfOperation, 0)
      end
    end

    # end optparse methods
    ######################

    def validate_command
      object = command[1]
      if object.nil?
        out.puts "No hosts pod specified.\n"
        out.puts parser
        self.exit_code = 1
        return false
      end
      object
    end

    def run
      # no subcommand chosen
      out.puts parser
      self.exit_code = 1
      return exit_code
    end

    private

    def _lookup(compute_resource, name)
      compute.send(compute_resource).find { |i| i.name == name }
    end

    # @raise OSC::UnknownServerAttribute if not found.
    def _lookup!(compute_resource, name)
      item = _lookup(compute_resource, name)
      if item.nil?
        items = compute.send(compute_resource)
        raise(OSC::UnknownServerAttribute, "Failed #{compute_resource} lookup. Could not find '#{name}' in:\n#{items.map { |i| i.name }.sort.pretty_inspect}")
      end
      item
    end
  end

  class Create < OpenStackControl
    def _banner(parser)
      parser.banner = "Usage: oscontrol create <pod> [options]"
      parser.separator ""
    end

    def _subcommand(parser)
      parser.separator "Create:"
      parser.separator ""
      parser.separator <<-EOS
  Creates a set of servers identified by <pod>.  To determine the
  characteristics of those servers, we extract host definitions, including
  flavor, from a beaker hosts file in #{beaker_hosts_path}/<pod>.hosts.
      EOS
      parser.separator ""
    end

    def run
      return exit_code unless validate_command

      pod = command[1]

      existing_servers = server_list
      hosts = get_pod_hosts(pod)
      hosts.each do |attrs|
        hostname = attrs['name']
        if !existing_servers.find { |s| s.name == hostname }
          instance = create_server(attrs)
          out.puts("Created: #{instance.name}")
        else
          out.puts "(Already created #{hostname}, skipping)"
        end
        #out.puts execute_openstack(
        #  'server',
        #  'add floating ip',
        #  hostname,
        #  floating_ips.pop,
        #)
      end
    end
  end

  class Drop < OpenStackControl
    def _banner(parser)
      parser.banner = "Usage: oscontrol drop <pod> [options]"
      parser.separator ""
    end

    def _subcommand(parser)
      parser.separator "Drop:"
      parser.separator ""
      parser.separator"  Deletes all servers defined in a Beaker <pod>.hosts files found in #{beaker_hosts_path}."
      parser.separator ""
    end

    def run
      return exit_code unless validate_command

      pod = command[1]

      get_pod_hosts(pod).each do |attrs|
        hostname = attrs['name']
        success = drop_server(hostname)
        out.puts "Dropped: #{hostname}" if success
      end
    end
  end

  class List < OpenStackControl
    def _banner(parser)
      parser.banner = "Usage: oscontrol list [pod] [options]"
      parser.separator ""
    end

    def _subcommand(parser)
      parser.separator "List:"
      parser.separator ""
      parser.separator "  Lists all servers, or all servers that hae been defined in a Beaker <pod>.hosts file found in #{beaker_hosts_path}."
      parser.separator ""
    end

    def run
      object = command[1]

      servers = server_list(object)
      servers.sort { |a,b| a.name <=> b.name }.each do |s|
        out.puts s.name
      end
    end
  end

  class Show < OpenStackControl
    def _banner(parser)
      parser.banner = "Usage: oscontrol show [host] [options]"
      parser.separator ""
    end

    def _subcommand(parser)
      parser.separator "Show:"
      parser.separator ""
      parser.separator "  Displays the OpenStack server details for the specified <host> if found."
      parser.separator ""
    end

    def run
      return exit_code unless validate_command

      hostname = command[1]

      server = get_server(hostname)
      if server.nil?
        self.exit_code = 1
        raise(OSC::UnknownHost, "Failed to find a host named '#{hostname}'.") if server.nil?
      end

      out.puts "#{server.class}: #{server.name}"
      image = compute.images.get(server.image['id'])
      out.puts "image: #{image.name}"
      flavor = compute.flavors.get(server.flavor['id'])
      out.puts "flavor: #{flavor.name}"
      out.puts "networks: #{server.networks}"
      out.puts "security_groups: #{server.security_groups.map { |sg| sg.name }}"
    end
  end

  # Used for parse errors or options like --help, --version that side step
  # normal command flow.
  class Noop < OpenStackControl
    def initialize(exit_code)
      self.exit_code = exit_code
    end

    def run
      exit exit_code
    end
  end
end
