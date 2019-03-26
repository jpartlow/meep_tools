require_relative '../spec_helper'

describe 'meep_tools::nfs_mount' do
  def config
    @config ||= begin
      boltdir = File.join(SpecHelpers.fixtures_path, 'boltdir')
      conf = Bolt::Config.new(Bolt::Boltdir.new(boltdir), {})
      conf.modulepath = [modulepath].flatten
      conf
    end
  end

  def inventory
    @inventory ||= Bolt::Inventory.from_config(config)
  end

  it do
    user = ENV['USER']
    home = ENV['HOME']

    expect_task('meep_tools::get_ip_addr')
      .with_targets(['some.node'])
      .always_return('address' => '10.5.6.7')
    expect_task('meep_tools::add_nfs_exports')
      .with_targets(['localhost'])
      .with_params(
        'source_dir' => "#{home}/work/src",
        'target_ip'  => '10.5.6.7'
      )
    expect_task('meep_tools::mount_nfs_dir')
      .with_targets(['some.node'])
      .with_params(
        'source_ip'       => '10.2.3.4',
        'source_dir'      => "#{home}/work/src",
        'local_mount_dir' => "/#{user}-src"
      )

    expect(run_plan('meep_tools::nfs_mount', 'nodes' => 'some.node')).to have_succeeded
  end
end
