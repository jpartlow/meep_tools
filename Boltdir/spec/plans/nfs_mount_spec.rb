require_relative '../spec_helper'

describe 'integration::nfs_mount' do
  it do
    result = run_plan('integration::nfs_mount', 'nodes' => 'localhost')
    pp result
  end
end
