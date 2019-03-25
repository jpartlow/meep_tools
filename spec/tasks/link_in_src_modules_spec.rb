require 'spec_helper'
require 'json'
require 'meep_tools/command_runner'

describe 'link_from_src' do
  include_context('task isolation')

  let(:task_params) do
    {
      :modules => ['puppet_enterprise','pe_manager']
    }
  end

  it do
    expect { load('tasks/link_in_src_modules.rb') }.to raise_error(RuntimeError, /Module puppet_enterprise not present/)
  end
end
