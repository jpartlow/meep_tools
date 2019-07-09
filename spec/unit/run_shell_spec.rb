require 'spec_helper'

require 'shared/test_executor'
require 'matchers/execute_with'

require 'run_shell'

describe 'RunShell' do
  class TestClass < RunShell
    def execute
      run('foo')
    end
  end

  let(:subject) { TestClass }

  it 'executes a command' do
    is_expected.to execute
      .and_invoke_with('args')
      .and_generate_commands('foo')
      .and_output('foo')
  end

  context 'actions' do
    class TestClassAction < RunShell
      def execute
        action('testing') do
          run('something')
          result = capture('other')
          if test("atest #{result}")
            run('test passed')
          else
            run('test failed')
          end
        end
      end
    end

    let(:green) { Regexp.escape("\e[32m") }
    let(:cyan) { Regexp.escape("\e[36m") }
    let(:grey) { Regexp.escape("\e[37m") }
    let(:off) { Regexp.escape("\e[0m") }

    let(:subject) { TestClassAction }

    before(:each) do
      TestExecutor.add_response('something', 'something result')
      TestExecutor.add_response('other', 'other_result')
      TestExecutor.add_response('test passed', 'passed')
      TestExecutor.add_response('test failed', 'failed')
    end

    it 'generates output when test is successful' do
      TestExecutor.add_response(/atest/, ['this will not be seen', true])

      is_expected.to execute
        .and_invoke_with('')
        .and_output(
%r{#{green}\* testing #{off}
  #{cyan}something#{off}
  #{cyan}other#{off}
  #{cyan}atest other_result#{off}
  #{cyan}test passed#{off}}m
        )
        .and_generate_commands([
          'something',
          'other',
          'atest other_result',
          'test passed',
        ])
    end

    it 'generates output when test fails' do
      TestExecutor.add_response(/atest/, ['this will not be seen', false])

      is_expected.to execute
        .and_invoke_with('')
        .and_output(
%r{#{green}\* testing #{off}
  #{cyan}something#{off}
  #{cyan}other#{off}
  #{cyan}atest other_result#{off}
  #{cyan}test failed#{off}}m
        )
        .and_generate_commands([
          'something',
          'other',
          'atest other_result',
          'test failed',
        ])
    end

    it 'generates debug output' do
      TestExecutor.add_response(/atest/, ['this will not be seen', true])

      is_expected.to execute
        .and_invoke_with('--debug')
        .and_output(
%r{#{green}\* testing #{off}
  #{cyan}something#{off}
    something result
      #{grey}status: #<TestExecutor::Status:0x[a-f0-9]+ @success=true>#{off}
  #{cyan}other#{off}
    other_result
      #{grey}status: #<TestExecutor::Status:0x[a-f0-9]+ @success=true>#{off}
  #{cyan}atest other_result#{off}
    this will not be seen
      #{grey}status: #<TestExecutor::Status:0x[a-f0-9]+ @success=true>#{off}
  #{cyan}test passed#{off}
    passed
      #{grey}status: #<TestExecutor::Status:0x[a-f0-9]+ @success=true>#{off}}m
        )
        .and_generate_commands([
          'something',
          'other',
          'atest other_result',
          'test passed',
        ])
    end
  end

  # Test capture and popen executors.
  context 'Executors' do
    let(:options) { {} }

    class TestExecutorClass
      include RunShellExecutable

      attr_accessor :options

      def initialize(options)
        self.options = options
      end

      def execute
        run('echo "hi"', options)
      end
    end

    let(:tester) { TestExecutorClass.new(options) }

    it 'captures output' do
      expect { tester.execute }.to output(<<~OUT
        \e[36mecho \"hi\"\e[0m
      OUT
      ).to_stdout
    end

    context 'streaming' do
      let(:options) { { streaming: true } }

      it 'streams output' do
        expect { tester.execute }.to output(<<~OUT
          \e[36mecho \"hi\"\e[0m
            hi
        OUT
        ).to_stdout
      end

      context 'with capture set' do
        let(:options) { { streaming: true, capture: true } }

        it 'just captures' do
          captured = nil
          expect { captured = tester.execute }.to output(<<~OUT
            \e[36mecho \"hi\"\e[0m
          OUT
          ).to_stdout
          expect(captured).to eq("hi\n")
        end
      end
    end
  end
end
