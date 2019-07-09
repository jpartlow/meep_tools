require 'run_shell'

module MeepTools
  module Threaded
    def run_threaded_product(description, _split_output: false, **variations, &block)
      product = generate_product_hashes(variations)
      threads = product.map do |variant|
        Thread.new do
          Thread.current[:variant] = variant
          Thread.current[:success] = action(
            "Starting: #{description} for #{variant} ...",
            streaming: _split_output
          ) do
            separate_output(_split_output, variant) do
              yield(variant)
            end
          end
        end
      end
      threads.each do |t|
        t.join
        out("Finished: #{description} for #{t[:variant]}")
      end
      threads.all? { |t| t[:success] }
    end

    def self.threaded_output_tmp_path
      '/tmp/meep_tools_threaded_output'
    end

    def threaded_output_tmp_path
      MeepTools::Threaded.threaded_output_tmp_path
    end

    def separate_output(separate, variant)
      old_io = self.io
      if separate
        FileUtils.mkdir(threaded_output_tmp_path) unless Dir.exist?(threaded_output_tmp_path)
        filename = "#{variant.to_a.join('_')}.out"
        filepath = "#{threaded_output_tmp_path}/#{filename}"
        new_io = File.open(filepath,'w')
        out("Redirecting #{variant} output to #{filepath}")
        self.io = new_io
      end
      yield
    ensure
      new_io.close if new_io
      self.io = old_io
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
