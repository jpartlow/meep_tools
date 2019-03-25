require 'spec_helper'
require 'json'
require 'meep_tools/command_runner'

describe 'link_from_src' do
  include_context('task isolation')

  let(:task_params) do
    { 
      "source_dir": "/tmp/a",
      "target_dir": "/tmp/b"
    }
  end

  it do
    expect { load('tasks/link_from_src.rb') }.to output(/^--> Replacing.*$/).to_stdout
    expect(MeepTools::TestRunner.fetch(params.to_json)).to eq([
      "mkdir -p /root/_meep_tools_backups/tmp",
      "mv -T /tmp/b /root/_meep_tools_backups/tmp/b",
      "ln -s /tmp/a /tmp/b"
    ])
  end
end
