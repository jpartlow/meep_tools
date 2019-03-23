require 'json'
require_relative 'command_runner.rb'
require_relative 'symlinker.rb'

module MeepTools
  class Executor
    include MeepTools::Symlinker
  
    # Hash of input parameters for the task.
    attr_accessor :params
    # Implementation of the command runner to use
    attr_accessor :runner
  
    def self.run(input = $stdin, &block)
      json = input.read 
      params = JSON.parse(json)

      runner = case params['_testing']
      when true then MeepTools::TestRunner.create(json)
      else MeepTools::CommandRunner.new
      end

      executor = self.new(runner, params)
      executor.execute(&block)
    end
  
    def initialize(runner, params)
      self.runner = runner
      self.params = params
    end
 
    def run(*commands)
      runner.run(*commands)
    end

    def execute
      yield(self, self.params)
    end
  end
end
