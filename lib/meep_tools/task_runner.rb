
def run(*cmd_array)
  puts(cmd_array.join(' '))
  output, status = Open3.capture2e(*cmd_array)
  puts output
  exit(1) unless status.success?
end
