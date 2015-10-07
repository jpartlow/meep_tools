#! /opt/puppetlabs/puppet/bin/ruby

require 'puppetclassify'
require 'pp'

module ClassificationTool

  def self.usage
    puts "USAGE: classifcation-tool.rb <command> <subcommand>"
    puts <<-EOS
    commands:

      perepo:

        subcommands:
          create - create a group '#{ClassificationTool::PERepo::NAME}' with the
                   initial pe_repo classes for the master for all platforms
          remove - remove this group
          update <agent_version> - update all classes in the group to <agent_version>
          show   - lit the pe_repo classes

      compile:

        subcommands:
          install <compile-master-hostname> - install a compile master on the given host
            ex: `classification-tool.rb compile install pe-201520-agent.puppetdebug.vlan`
          add_platforms <platform1> <platform2> - add just the given platforms
            ex: `classification-tool.rb perepo add_platforms el_7_x86_64 ubuntu_1404_amd64`
            ex: (must match the pe_repo::platform::<class>)
    EOS
    exit 1
  end

  def self.hostname
    @hostname ||= `/opt/puppetlabs/bin/facter fqdn`.strip
  end

  def self.classifier_hostname
    @classifier_hostname ||= `grep server /etc/puppetlabs/puppet/classifier.yaml | cut -d' ' -f2`.strip
  end

  # URL of classifier as well as certificates and private key for auth
  def self.auth_info
    @auth_info ||= {
      "ca_certificate_path" => "/etc/puppetlabs/puppet/ssl/certs/ca.pem",
      "certificate_path"    => "/etc/puppetlabs/puppet/ssl/certs/#{self.hostname}.pem",
      "private_key_path"    => "/etc/puppetlabs/puppet/ssl/private_keys/#{self.hostname}.pem"
    }
  end

  def self.classifier
    classifier_url = "https://#{classifier_hostname}:4433/classifier-api"
    PuppetClassify.new(classifier_url, auth_info)
  end

  class Command
    attr_reader :classifier

    def initialize
      @classifier = ClassificationTool.classifier
    end

    def dispatch(subcommand, *args)
      ClassificationTool.usage if subcommand.nil? || !respond_to?(subcommand)
      send(subcommand, *args)
    end

    def id
      classifier.groups.get_group_id(_name)
    end

    def show
      pp classifier.groups.get_group(id)
    end
  end

  class PERepo < Command

    NAME = "pe-repo-classes"
    CLASSES = {
      #    "pe_repo::platform::aix_53_power" => {},
      #    "pe_repo::platform::aix_61_power" => {},
      #    "pe_repo::platform::aix_71_power" => {},
          "pe_repo::platform::debian_6_amd64" => {},
          "pe_repo::platform::debian_6_i386" => {},
          "pe_repo::platform::debian_7_amd64" => {},
          "pe_repo::platform::debian_7_i386" => {},
          "pe_repo::platform::debian_8_amd64" => {},
          "pe_repo::platform::debian_8_i386" => {},
      #    "pe_repo::platform::el_4_i386" => {},
      #    "pe_repo::platform::el_4_x86_64" => {},
          "pe_repo::platform::el_5_i386" => {},
          "pe_repo::platform::el_5_x86_64" => {},
          "pe_repo::platform::el_6_i386" => {},
          "pe_repo::platform::el_6_x86_64" => {},
          "pe_repo::platform::el_7_x86_64" => {},
          "pe_repo::platform::fedora_21_i386" => {},
          "pe_repo::platform::fedora_21_x86_64" => {},
      #    "pe_repo::platform::fedora_22_i386" => {},
      #    "pe_repo::platform::fedora_22_x86_64" => {},
          "pe_repo::platform::osx_1010_x86_64" => {},
          "pe_repo::platform::osx_109_x86_64" => {},
          "pe_repo::platform::sles_10_i386" => {},
          "pe_repo::platform::sles_10_x86_64" => {},
          "pe_repo::platform::sles_11_i386" => {},
          "pe_repo::platform::sles_11_x86_64" => {},
          "pe_repo::platform::sles_12_x86_64" => {},
          "pe_repo::platform::solaris_10_i386" => {},
          "pe_repo::platform::solaris_10_sparc" => {},
      #    "pe_repo::platform::solaris_11_i386" => {},
      #    "pe_repo::platform::solaris_11_sparc" => {},
          "pe_repo::platform::ubuntu_1004_amd64" => {},
          "pe_repo::platform::ubuntu_1004_i386" => {},
          "pe_repo::platform::ubuntu_1204_amd64" => {},
          "pe_repo::platform::ubuntu_1204_i386" => {},
          "pe_repo::platform::ubuntu_1404_amd64" => {},
          "pe_repo::platform::ubuntu_1404_i386" => {},
          "pe_repo::platform::ubuntu_1504_amd64" => {},
          "pe_repo::platform::ubuntu_1504_i386" => {},
          "pe_repo::platform::windows_i386" => {},
          "pe_repo::platform::windows_x86_64" => {},
    }

    def create
      classifier.groups.create_group(
        "name" => NAME,
        "classes" => CLASSES,
        "rule" => [ "and",  [ '=', 'name', ClassificationTool.hostname ] ],
        "parent"=>"00000000-0000-4000-8000-000000000000"
      )
    end

    def remove
      classifier.groups.delete_group(id)
    end

    def update(agent_version = nil)
      ClassificationTool.usage unless agent_version

      classes = CLASSES.inject({}) do |hash,row|
	hash[row[0]] = { "agent_version" => agent_version }
	hash
      end

      classifier.groups.update_group(
	"id" => id,
	"classes" => classes
      )
    end

    private

    def _name
      NAME
    end
  end

  class CompileMaster < Command
    NAME = "PE Master"

    def install(compile_master_hostname = nil)
      ClassificationTool.usage unless compile_master_hostname

      current_group = classifier.groups.get_group(id)
      new_rule = current_group["rule"] + [[ '=', 'name', compile_master_hostname ]]

      classifier.groups.update_group(
        "id" => id,
        "rule" => new_rule,
      )
    end

    def add_platforms(*platforms)
      ClassificationTool.usage if platforms.empty?

      classes = platforms.inject({}) do |hash,platform|
        hash["pe_repo::platform::#{platform}"] = {}
        hash
      end

      current_group = classifier.groups.get_group(id)
      new_classes = current_group["classes"].merge(classes)

      classifier.groups.update_group(
	"id" => id,
	"classes" => new_classes
      )
    end

    private

    def _name
      NAME
    end
  end
end

command = ARGV.shift
subcommand = ARGV.shift

tool = case command
when 'perepo' then
  ClassificationTool::PERepo.new
when 'compile' then
  ClassificationTool::CompileMaster.new
else
  ClassificationTool.usage
end

tool.dispatch(subcommand, *ARGV)
