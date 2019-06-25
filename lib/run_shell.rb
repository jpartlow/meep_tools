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
    attr_accessor :io, :level, :muzzle, :original_muzzle

    def initialize(io: $stdout, level: 0, muzzle: false, original_muzzle: false)
      self.io = io
      self.level = level
      self.muzzle = muzzle
      self.original_muzzle = original_muzzle
    end

    def to_h
      {
        io: self.io,
        level: self.level,
        muzzle: self.muzzle,
        original_muzzle: self.original_muzzle,
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
    self.runshell_context.muzzle = value
  end

  def original_muzzle
    self.runshell_context.original_muzzle
  end

  def original_muzzle=(value)
    self.runshell_context.original_muzzle = value
  end

  def level
    self.runshell_context.level
  end

  def level=(value)
    self.runshell_context.level = value
  end

  def io
    self.runshell_context.io
  end

  def io=(value)
    self.runshell_context.io = value
  end

  # Abstraction of the actual shell execution.
  class Executor
    def exec(command, options = {})
      Open3.capture2e(command, options)
    end
  end

  # Other (test) Executor implementations may be mocked here.
  def self.executor
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
    self.original_muzzle = muzzle
    self.muzzle = options[:muzzle]
    out(green("* #{message} "))
    out(grey('(output suppressed...run with --debug for all output)'), :bump_level => 1) if muzzled? && !debugging?
    self.level += 1
    successful = yield
    if !successful
      out(red("Action failed!"))
      raise(ActionFailed, "Failed on step: #{message}")
    end
    return successful
  ensure
    self.muzzle = original_muzzle
    self.level -= 1
  end

  def run(command, options = {})
    capture = options[:capture]
    test = options[:test]

    process_options = options.slice(:chdir)
    stdout_and_err, status = RunShellExecutable.executor.exec(command, process_options)

    failed = !status.success?
    out(cyan(command)) if debugging? || !muzzled?
    if debugging? || (!muzzled? && failed && !test)
      output = status.success? ? stdout_and_err : red(stdout_and_err)
      out(output, :bump_level => 1)
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
