module MeepTools
  module Symlinker
    PUPPET_MODULES_PATH     = "/opt/puppetlabs/puppet/modules"
    ENTERPRISE_MODULES_PATH = "/opt/puppetlabs/server/data/environments/enterprise/modules"

    def remote_src_dir
      "/#{ENV['USER']}-src"
    end

    def available_modules(modules_root = remote_src_dir)
      pem_modules = Dir.glob("#{modules_root}/puppet-enterprise-modules/modules/*").inject({}) do |hash,path|
        mod = path.split('/').last
        hash[mod] = path
        hash
      end
      other_modules = Dir.glob("#{modules_root}/pe-modules/*").inject({}) do |hash,path|
        mod = path.split('/').last.gsub(/^puppetlabs-/,'')
        hash[mod] = path
        hash
      end
      pem_modules.merge(other_modules)
    end

    def link_module(module_name, link: 'both', modules_root: remote_src_dir)
      base_module = ['both','base'].include?(link) && module_name != 'pe_manager'
      enterprise_module = ['both','enterprise'].include?(link)

      available = available_modules(modules_root)
      if  source_dir = available[module_name]
        link_directory(source_dir, "#{PUPPET_MODULES_PATH}/#{module_name}") if base_module
        link_directory(source_dir, "#{ENTERPRISE_MODULES_PATH}/#{module_name}") if enterprise_module
        if !(base_module || enterprise_module)
          puts "--> Note: requested #{link} link of #{module_name} skipped because it is not applicable."
        end
      else
        raise(RuntimeError, "Module #{module_name} not present. Available modules:\n#{available.keys.pretty_inspect}")
      end
    end

    def link_directory(source_dir, target_dir)
      puts "--> Replacing #{target_dir} with a link to #{source_dir}"
      if !File.symlink?(target_dir)
        backup_root = "/root/_meep_tools_backups"
        backup = "#{backup_root}#{target_dir}"
        if !File.exist?(backup)
          run('mkdir', '-p', File.dirname(backup))
          run('mv', '-T', target_dir, backup)
        else
          run('rm', '-rf', target_dir)
        end
        run('ln', '-s', source_dir, target_dir)
      else
        puts " * link already set"
      end
    end
  end
end
