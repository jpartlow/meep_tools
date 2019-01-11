# This class is us used to mock the RunShell.executor with a test class that
# records commands and can return preset responses for testing tools that
# interact with the command line through the RunShell module.
#
# The matchers/execute_with.rb matcher makes use of this for testing.
#
class TestExecutor

  def self.commands
    @commands ||= []
  end

  def self.responses
    @responses ||= {
      /foo/ => ['bar', Status.new],
    }
  end

  def self.find_response(command)
    response = TestExecutor.responses[command]
    if response.nil?
      tests = TestExecutor.responses.keys.select { |k| k.kind_of?(Regexp) }
      matched_command = tests.find do |test|
        test.match(command)
      end
      response = TestExecutor.responses[matched_command]
    end
    response ||=  ["", Status.new]
    return *response
  end

  def self.clear
    @commands = []
  end

  def self.add_response(command, response)
    _response = response.kind_of?(Array) ?
      [response[0], Status.new(response[1])] :
      [response, Status.new]
    responses[command] = _response
  end

  class Status
    attr_accessor :success

    def initialize(success = true)
      self.success = success
    end

    def success?
      success == true || success == 0
    end
  end

  def exec(command)
    TestExecutor.commands << command
    response = TestExecutor.find_response(command)
    return *response
  end
end
