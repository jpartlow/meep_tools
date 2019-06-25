require 'spec_helper'
require 'meep_tools/threaded'

describe 'MeepTools::Threaded' do
  class TestThreads
    include MeepTools::Threaded

    attr_accessor :output

    def initialize
      @output = []
    end

    # Simulate RunShell action()
    def action(message, &block)
      out message
      yield
    end

    # Simulate RunShell out()
    def out(message)
      output << message
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
end
