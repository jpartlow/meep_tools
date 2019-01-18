require 'open3'
require 'pp'
require 'parse_options'

# Shared code for executing commands through the shell.
# Expects the class it is included in to have an io() method that
# returns an IO object intended to receive the output of executed commands.
module RunShellExecutable

  attr_accessor :io, :debug, :muzzle, :original_muzzle

  class ActionFailed < StandardError; end

  # Whether or not something has set @debug for additional output detail.
  def debugging?
    self.debug
  end

  # Whether or not something has set @muzzle to true to temporarily block output.
  def muzzled?
    self.muzzle
  end

  def level
    Thread.current[:level] ||= 0
  end

  def level=(value)
    Thread.current[:level] = value
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
    io.puts indent(string, bump_level)
    return true
  end

  def indent(string, bump_level = 0)
    indentation = "  " * (level + bump_level)
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

  class Executor
    def exec(command, options = {})
      Open3.capture2e(command, options)
    end
  end

  def self.executor
    Executor.new
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
  def capture(command)
    run(command, :capture => true)
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
