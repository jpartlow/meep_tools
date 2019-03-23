module MeepTools
  module Symlinker
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
