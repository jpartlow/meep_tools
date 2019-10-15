require 'spec_helper'

describe 'meep_tools::build_pg_extension' do
  it do
    # bolt_spec doesn't yet allow mocking of subplans
  #  expect_plan('facts')
  #    .with_targets(['some.node'])
  #    .return({
  #      'os' => {
  #        'name' => 'RedHat',
  #      }
  #    })
  #  expect(run_plan('meep_tools::build_pg_extension', 'nodes' => 'some.node', 'extension' => 'pglogical', 'pe_family' => '2019.2', 'postgres_version' => '11', 'puppet_enterprise_vanagon_dir' => '/some/where')).to have_succeeded
  end
end
