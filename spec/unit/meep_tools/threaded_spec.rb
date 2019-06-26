require 'spec_helper'
require 'meep_tools/threaded'

describe 'MeepTools::Threaded' do
  class TestThreads
    include MeepTools::Threaded

    attr_accessor :io

    def initialize
      @io = StringIO.new
    end

    # Simulate RunShell action()
    def action(message, **options, &block)
      out message
      yield
    end

    # Simulate RunShell out()
    def out(message)
      io.puts(message)
      true
    end

    def output
      io.rewind
      io.readlines.map { |l| l.chomp }
    end
  end

  let(:tester) { TestThreads.new }

  context 'run_threaded_product' do
    it do
      variations = {
        foo: ['bar','baz']
      }
      expect(
        tester.run_threaded_product('Testing a thread', **variations) do |variant|
          tester.out "variation: #{variant}"
        end
      ).to eq(true)
      expect(tester.output).to match_array([
        'Starting: Testing a thread for {:foo=>"bar"} ...',
        'variation: {:foo=>"bar"}',
        'Finished: Testing a thread for {:foo=>"bar"}',
        'Starting: Testing a thread for {:foo=>"baz"} ...',
        'variation: {:foo=>"baz"}',
        'Finished: Testing a thread for {:foo=>"baz"}',
      ])
    end
  end

  context 'generate_product_hashes' do
    it 'raises an erorr if not given a hash' do
      expect { tester.generate_product_hashes('foo') }.to raise_error(ArgumentError, /Expected variants to be a Hash of Arrays, got/i)
    end 

    it 'returns first array if there is only one' do
      variations = {
        foo: [1,2]
      }
      expect(tester.generate_product_hashes(variations)).to eq([
        { foo: 1 },
        { foo: 2 }, 
      ])
    end

    it 'returns product of two arrays' do
      variations = {
        foo: [1,2],
        bar: ['a','b'],
      }
      expect(tester.generate_product_hashes(variations)).to match_array([
        {
          foo: 1,
          bar: 'a'
        },
        {
          foo: 1,
          bar: 'b'
        },
        {
          foo: 2,
          bar: 'a'
        },
        {
          foo: 2,
          bar: 'b'
        },
      ])
    end

    it 'returns product of three or more arrays' do
      variations = {
        foo: [1,2],
        bar: ['a','b'],
        baz: ['i','ii'],
      }
      expect(tester.generate_product_hashes(variations)).to match_array([
        {
          foo: 1,
          bar: 'a',
          baz: 'i'
        },
        {
          foo: 1,
          bar: 'a',
          baz: 'ii',
        },
        {
          foo: 1,
          bar: 'b',
          baz: 'i'
        },
        {
          foo: 1,
          bar: 'b',
          baz: 'ii'
        },
        {
          foo: 2,
          bar: 'a',
          baz: 'i'
        },
        {
          foo: 2,
          bar: 'a',
          baz: 'ii',
        },
        {
          foo: 2,
          bar: 'b',
          baz: 'i'
        },
        {
          foo: 2,
          bar: 'b',
          baz: 'ii',
        },
      ])
    end

    it 'handles non-array elements' do
      variations = {
        foo: [1,2],
        bar: 'bob',
      }
      expect(tester.generate_product_hashes(variations)).to match_array([
        {
          foo: 1,
          bar: 'bob'
        },
        {
          foo: 2,
          bar: 'bob'
        },
      ])
    end
  end

  context 'separate_output' do
    around(:each) do |example|
      testout = "#{MeepTools::Threaded.threaded_output_tmp_path}/a_1_b_2.out"
      begin
        example.run
      ensure
        FileUtils.rm(testout) if File.exist?(testout)
      end
    end

    it 'just yields if told not to separate' do
      tester.separate_output(false, { a: 1, b: 2 }) do
        tester.out('not to file')
      end
      expect(tester.output).to eq([
        'not to file',
      ])
    end

    it 'separates output to a file based on variant' do
      tester.separate_output(true, { a: 1, b: 2 }) do
        tester.out('to file')
      end
      expect(tester.output).to eq([
        "Redirecting {:a=>1, :b=>2} output to /tmp/meep_tools_threaded_output/a_1_b_2.out"
      ])
      expect(File.read("#{tester.threaded_output_tmp_path}/a_1_b_2.out")).to eq("to file\n")
    end
  end

  context 'streaming threads' do
    class TestStreamingThreads
      include MeepTools::Threaded
      include RunShellExecutable
    end

    let(:tester) { TestStreamingThreads.new }

    def remove_files(pattern)
      Dir.glob(pattern).each do |file|
        FileUtils.rm(file) if File.exist?(file)
      end
    end

    around(:each) do |example|
      testout = "#{MeepTools::Threaded.threaded_output_tmp_path}/bar_*.out"
      begin
        example.run
      ensure
        remove_files(testout)
      end
    end

    it do
      stdout= StringIO.new
      tester.io = stdout

      expect(
        tester.run_threaded_product(
          'Test',
          _split_output: true,
          foo: [1,2],
          bar: ['a','b']
        ) do |variant|
          tester.run("echo '#{variant}'")
        end
      ).to eq(true)

      stdout.rewind
      output = stdout.readlines

      redirected = output.grep(/Redirecting/)
      expect(redirected.size).to eq(4)

      redirected.each do |r|
        matcher = r.match(/Redirecting (.*) output to (.*)$/)
        variant = matcher[1]
        file = matcher[2]
        expect(File.read(file)).to match(variant)
      end
    end

#    # Uncomment and run to observe timing of streamed output to files
#    it 'manual threading test' do
#      tester.run_threaded_product(
#        'Test',
#        _split_output: true,
#        foo: [1,2],
#        bar: ['a','b']
#      ) do |variant|
#        [
#          'echo "starting"; sleep 2',
#          %Q{ruby -e '5.times do $stdout.puts %q{middling #{variant}}; $stdout.flush; sleep 1; end'},
#          'echo "ending"; sleep 2',
#        ].each do |c|
#          tester.run(c)
#        end
#      end
#    end
  end
end
