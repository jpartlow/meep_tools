RSpec::Matchers.define(:have_succeeded) do |_expected|
  match do |result|
    result.ok?
  end

  failure_message do |result|
    "Expected plan to succeed, but got '#{result.status}':\n#{result.pretty_inspect}"
  end
end
