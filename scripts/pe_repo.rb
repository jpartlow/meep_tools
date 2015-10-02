require 'puppetclassify'

module ClassificationTool

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

  class PERepo
 
    NAME = "pe-repo-classes"

    attr_reader :classifier
  
    def init
      @classifier = ClassificationTool.classifier
    end
  
    def create
      classifier.groups.create_group(
        "name" => NAME,
        "classes" => {
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
        },
        "rule" => [ "and",  [ '=', 'name', hostname ] ],
        "parent"=>"00000000-0000-4000-8000-000000000000"
      )
    end

    def id
      classifier.groups.get_groupid(NAME)
    end

    def remove
      classifier.groups.delete_group(id)
    end
  end
end

if ARGV.empty?
  puts "USAGE: ruby pe_repo.rb <command>"
  puts <<-EOS
  commands:
    create - create a group '#{ClassificationTool::PERepo::NAME}' with the
             initial pe_repo classes for the master for all platforms
    remove - remove this group
    update <agent_version> - update all classe in the group to <agent_version>
  EOS
  exit 1
end

command = ARGV.shift
pe_repo = ClassificationTool::PERepo.new
pe_repo.send(command, ARGV.shift)
