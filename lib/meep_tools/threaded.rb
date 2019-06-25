require 'run_shell'

module MeepTools
  module Threaded
    def run_threaded_product(description, **variations, &block)
      product = generate_product_hashes(variations)
      threads = product.map do |variant|
        Thread.new do
          Thread.current[:variant] = variant
          RunShellExecutable.thread_context = RunShellExecutable.copy_main_context
          Thread.current[:success] = action("Starting: #{description} for #{variant} ...") do
            yield(variant)
          end
        end
      end
      threads.each do |t|
        t.join
        out("Finished: #{description} for #{t[:variant]}")
      end
      threads.all? { |t| t[:success] }
    end

    def sorted_symbolized_keys(hash)
      hash.keys.map { |k| k.to_sym }.sort 
    end

    # Takes a hash of arrays, and returns an array of hashes of
    # the cartesian product of the value arrays keyed per the
    # original hash. Also ensures that that the keys are symbols.
    #
    # So given:
    #
    #   {
    #     'foo' => [1,2],
    #     'bar' => ['a','b'],
    #   }
    #
    # returns:
    #
    #   [
    #     {
    #       'foo' => 1,
    #       'bar' => 'a',
    #     },
    #     {
    #       'foo' => 1,
    #       'bar' => 'b',
    #     },
    #     {
    #       'foo' => 2,
    #       'bar' => 'a',
    #     },
    #     {
    #       'foo' => 2,
    #       'bar' => 'b',
    #     },
    #   ]
    def generate_product_hashes(variants)
      raise(ArgumentError, "Expected variants to be a Hash of Arrays, got: #{variants}") if !variants.is_a?(Hash)
      sorted_keys = variants.keys.sort
      sorted_value_arrays = sorted_keys.map { |k| Array(variants[k]) }
      product = case sorted_value_arrays.size
      when 1 then sorted_value_arrays[0]
      else
        sorted_value_arrays[0].product(*sorted_value_arrays[1..-1])
      end
      product.map do |p|
        sorted_keys.zip(Array(p)).to_h
      end
    end
  end
end
