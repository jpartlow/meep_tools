RSpec::Matchers.define(:execute) do
  match do |klass_or_instance|
    @stdout_tmp = StringIO.new

    TestExecutor.clear

    allow(RunShellExecutable).to receive(:executor).and_return(TestExecutor.new)

    if defined?(Thor) == 'constant' && klass_or_instance.kind_of?(Thor)
      @runner = klass_or_instance
      @runner.io = @stdout_tmp
    else
      begin
        if defined?(Thor) == 'constant' && klass_or_instance < Thor
          @result = klass_or_instance.invoke(@args.split, @stdout_tmp)
        else
          @runner = klass_or_instance.invoke(@args.split, @stdout_tmp)
        end
      rescue ParseOptions::HelpExit
        @result = true # would exit with a 0
      end
    end

    begin
      @result = @runner.send(@function || :execute) if @runner
    rescue RunShell::ActionFailed => e
      @failure_exception = e
    end

    @output_matched = (@output_expressions || []).all? do |oe|
      @stdout_tmp.string.match(oe)
    end

    @commands_matched = (@command_expressions || []).all? do |ce|
      TestExecutor.commands.find { |c| c.match(ce) }
    end

    @expected_result = true if !instance_variable_defined?(:@expected_result)
    @result_matched = @result == @expected_result

    if @yield_to
      @yield_to.call(@runner)
    end

    @result_matched && @output_matched && @commands_matched
  end

  # If we creating the test instance ourselves, this will pass in command line args
  chain(:and_invoke_with) do |args|
    @args = args || ''
  end

  # Instead of calling execute() on the invoked command, call the passed function.
  chain(:and_call) do |function|
    @function = function.to_sym
  end

  # Yield the test object we create for additional testing
  chain(:and_yield_test_instance) do |&block|
    @yield_to = block
  end

  chain(:and_return) do |expected_result|
    @expected_result = expected_result
  end

  chain(:and_output) do |output_expressions|
    @output_expressions = [output_expressions].flatten
  end

  chain(:and_generate_commands) do |command_expressions|
    @command_expressions = [command_expressions].flatten
  end

  chain(:and_fail_with) do |failure_expression|
    @expected_result = nil
    @failure_expected = true
    @output_expressions ||= []
    @output_expressions << failure_expression
    @output_expressions << /Action failed!/
  end

  failure_message do |actual|
    message = ["expected that #{@runner} would:"]
    message << " * return '#{@expected_result}' but it returned '#{@result}'" unless @result_matched
    if !@output_matched
      message << " * have found these expressions:"
      message << @output_expressions.pretty_inspect
      message << "   in this output:"
      message << @stdout_tmp.string
    end
    if !@commands_matched
      message << " * have found these commands:"
      message << @command_expressions.pretty_inspect
      message << "   in this command list:"
      message << TestExecutor.commands.pretty_inspect
    end
    message.join("\n")
  end
end


