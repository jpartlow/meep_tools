require 'spec_helper'
require 'json'
require 'meep_tools/command_runner'

describe 'link_from_src' do
  let(:params) do
    { 
      "_testing": true,
      "source_dir": "/tmp/a",
      "target_dir": "/tmp/b"
    }
  end
  let(:input) { StringIO.new(params.to_json) }

  around(:each) do |example|
    begin
      stdin = $stdin
      $stdin = input
      example.run
    ensure
      $stdin = stdin
    end    
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
