require 'optparse'

# These are utility option parsing classes for use with RunShell and scripts
# relying on Runshell for command execution.
module ParseOptions

  class HelpExit < RuntimeError; end

  # Placeholder for specific help text for a subcommand
  def command_banner
    ''
  end

  # Overwrite as necessary in the Options class of your script.
  def common_banner
    <<-EOS
Usage:
  #{__FILE__} [options]

    EOS
  end

  # Placeholder for specific option parsers for the subcommand
  def set_command_options(parser); end

  def option_parser
    parser = OptionParser.new

    parser.banner = common_banner + command_banner

    set_command_options(parser)

    parser.on('--debug', 'Add full command output') do
      self.options[:debug] = true
    end

    parser.on('-h', '--help', 'This message.') do
      io.puts parser
      raise ParseOptions::HelpExit
    end

    return parser
  end

  # Main routine for parsing commandline options
  def parse_options(args = {})
    self.option_parser.parse!(args)
  rescue OptionParser::InvalidOption => e
    io.puts option_parser
    io.puts "\n!! #{e.message}\n"
    raise(e)
  end
end

# Subclassed by each subcommand for option parsing.
class BaseOptions
  include ParseOptions

  attr_accessor :options, :commands, :io

  def initialize(args, io = $stdout)
    self.io = io
    self.options = {}
    self.commands = parse_options(args)
  end
end
