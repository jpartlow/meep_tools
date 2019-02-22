require_relative '../spec_helper'

describe 'integration::nfs_mount' do
  it do
    expect_task('meep_tools::get_ip_addr').always_return('1.2.3.4')
    expect(run_plan('meep_tools::nfs_mount', 'nodes' => 'localhost')).to be
  end
end
