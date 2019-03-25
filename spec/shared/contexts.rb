RSpec.shared_context('task isolation') do
  let(:params) do
    {
      "_testing": true,
    }.merge(task_params)
  end
  let(:input) { StringIO.new(params.to_json) }

  around(:each) do |example|
    begin
      stdin = $stdin
      $stdin = input
      example.run
    ensure
      $stdin = stdin
    end
  end
end
