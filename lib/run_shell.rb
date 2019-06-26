require 'open3'
require 'pp'
require 'parse_options'

# Shared code for executing commands through the shell.
# Expects the class it is included in to have an io() method that
# returns an IO object intended to receive the output of executed commands.
module RunShellExecutable

  # Treating the debug flag as global state
  attr_accessor :debug

  class ActionFailed < StandardError; end

  # Holds the state for one Thread's output activity.
  class Context
    attr_accessor :io, :level, :muzzle, :streaming

    def initialize(io: $stdout, level: 0, muzzle: false, streaming: false)
      self.io = io
      self.level = level
      self.muzzle = muzzle
      self.streaming = streaming
    end

    def to_h
      {
        io: self.io,
        level: self.level,
        muzzle: self.muzzle,
        streaming: self.streaming
      }
    end
  end

  # The Context object for the main thread, stored in an instance
  # variable so that non-threaded actions don't need to worry about
  # Thread variables.
  def main_context
    @main_context ||= Context.new
  end

  # The Context object for any Thread other than main.
  # Since this is a Thread variable, we can vary output
  # per Thread if necessary.
  def thread_context
    Thread.current[:runshell_context] ||= Context.new(main_context.to_h)
  end

  # The Context object for the current thread. Controls what IO we
  # use for output, the current output level and muzzle settings.
  # Defaults to main_context() if this is Thread.main.
  def runshell_context
    Thread.current == Thread.main ?
      main_context :
      thread_context
  end

  def muzzle
    self.runshell_context.muzzle
  end

  def muzzle=(value)
    self.runshell_context.muzzle = !!value
  end

  def level
    self.runshell_context.level
  end

  def level=(value)
    self.runshell_context.level = value.to_i
  end

  def io
    self.runshell_context.io
  end

  def io=(value)
    raise(ArgumentError, "Expected an IO instance; got: '#{value}'") if !io.kind_of?(IO) && !io.kind_of?(StringIO)
    self.runshell_context.io = value
  end

  def streaming
    self.runshell_context.streaming
  end

  def streaming=(value)
    self.runshell_context.streaming = !!value
  end

  # Abstraction of the actual shell execution.
  class Executor
    def exec(command, options = {}, &_block)
      Open3.capture2e(command, options)
    end
  end

  # Non blocking shell execution implementation. Streams output.
  class StreamingExecutor
    def exec(command, options = {}, &block)
      status = Open3.popen2e(command, options) do |stdin, stdout_and_err, wait_thr|
        stdin.close
        stdout_and_err.sync = true
        until stdout_and_err.eof?
          yield(stdout_and_err)
        end
        wait_thr.value
      end
      return '', status
    end
  end

  # Other (test) Executor implementations may be mocked here.
  # @param streaming [Boolean] if true will use the StreamingExecutor instead.
  def self.executor(streaming = false)
    streaming ?
      StreamingExecutor.new :
      Executor.new
  end

  # Whether or not something has set @debug for additional output detail.
  def debugging?
    self.debug
  end

  # Whether or not something has set @muzzle to true to temporarily block output.
  def muzzled?
    self.muzzle
  end

  def colorize(color_code, string)
    "\e[#{color_code}m#{string}\e[0m"
  end

  def red(string)
    colorize(31, string)
  end

  def green(string)
    colorize(32, string)
  end

  def cyan(string)
    colorize(36, string)
  end

  def grey(string)
    colorize(37, string)
  end

  def out(string, options = {})
    bump_level = options[:bump_level] || 0
    self.io.puts(indent(string, bump_level))
    return true
  end

  def indent(string, bump_level = 0)
    indentation = "  " * (self.level + bump_level)
    string.split("\n").map { |s| indentation + s }.join("\n")
  end

  def action(message, options = {})
    original_muzzle = muzzle
    original_streaming = streaming
    self.muzzle = options[:muzzle]
    self.streaming = options[:streaming]

    out(green("* #{message} "))
    out(grey('(output suppressed...run with --debug for all output)'), :bump_level => 1) if muzzled? && !debugging?
    self.level += 1

    # Do the action
    successful = yield

    if !successful
      out(red("Action failed!"))
      raise(ActionFailed, "Failed on step: #{message}")
    end
    return successful
  ensure
    self.muzzle = original_muzzle
    self.streaming = original_streaming
    self.level -= 1
  end

  def run(command, options = {})
    capture = options[:capture]
    test = options[:test]
    stream_output = options[:streaming]
    stream_output = streaming if stream_output.nil?

    if capture && stream_output
      stream_output = false
      if debugging? && capture && options[:streaming]
        out(grey("RunShell.run() was called with both the capture and the streaming flag set to true. The streaming flag will be ignored so that we capture output."))
        out(grey(backtrace.pretty_inspect), :bump_level => 1)
      end
    end

    out(cyan(command)) if debugging? || !muzzled?

    process_options = options.slice(:chdir)
    stdout_and_err, status = RunShellExecutable.executor(stream_output).exec(command, process_options) do |pipe_io|
      # Block only used by the StreamingExecutor.
      nextline = pipe_io.gets
      out(nextline, :bump_level => 1)
      # Flush the output
      io.fsync
    end

    failed = !status.success?
    if debugging? || (!muzzled? && failed && !test)
      output = status.success? ? stdout_and_err : red(stdout_and_err)
      out(output, :bump_level => 1) if !output.empty?
      out(grey("status: #{status.pretty_inspect.chomp!}"), :bump_level => 2 )
    end
    return capture ? stdout_and_err : status.success?
  end

  # Execute a command and return the captured stdout and err streams (in one String).
  def capture(command, options = {})
    run(command, options.merge(:capture => true))
  end

  # Execute a command and return true for a successful status or false if it fails.
  # Failure is not printed to stdout unless debugging.
  def test(command)
    run(command, :test => true)
  end
end

# Abstract class to inherit from when building a tool that runs commands to the shell.
# The execute() method must be overwritten.
class RunShell
  include RunShellExecutable

  class Options < BaseOptions; end

  attr_accessor :options

  def self.invoke(args, stdout_io = $stdout)
    parser = self::Options.new(args, stdout_io)
    self.new(parser.options.merge(:stdout_io => stdout_io))
  end

  def initialize(options)
    self.options = options
    self.io = options[:stdout_io] || $stdout
    self.debug = options[:debug]
    self.level = options[:level] || 0
  end

  def execute
    fail("Reimplement in a concrete class.")
  end
end
