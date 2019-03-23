require 'open3'

module MeepTools
  class CommandRunner
    def run(*cmd_array)
      puts(cmd_array.join(' '))
      output, status = Open3.capture2e(*cmd_array)
      puts output
      exit(1) unless status.success?
      return status
    end
  end

  # Used for spec testing
  class TestRunner
    class Status < Process::Status
      attr_reader :exitstatus

      def self.new(*args)
        i = self.allocate
        i.send(:initialize,*args)
        i
      end

      def initialize(exitstatus)
        @exitstatus = exitstatus
      end
    end

    # Keeps a log of commands in the class keyed against the given set of 
    # initializing params. Command log may be fetched with TestRunner.fetch.
    #
    # @param params [String] Initializing parameters used to invoke an execution
    #   (of the overall task, not of individual commands); used to key the hash
    #   of command execution logs for the returned TestRunner.
    # @return TestRunner instance
    def self.create(params)
      @commands ||= {}
      commands = @commands[params] = []
      TestRunner.new(commands)
    end

    def self.fetch(params)
      @commands ||= {}
      @commands[params] || []
    end

    attr_accessor :commands

    def initialize(commands = [])
      self.commands = commands
    end

    def run(*cmd_array)
      self.commands << cmd_array.join(' ')
      Status.new(0)
    end
  end
end
