require_relative '../spec_helper'

describe 'integration::nfs_mount' do
  it do
    user = ENV['USER']
    home = ENV['HOME']

    expect_task('meep_tools::get_ip_addr').always_return('address' => '1.2.3.4')
    expect_task('meep_tools::add_nfs_exports').with_params(
      'source_dir' => "#{home}/work/src",
      'target_ip'  => '1.2.3.4'
    )
    expect(run_plan('meep_tools::nfs_mount', 'nodes' => 'localhost')).to be
  end
end
