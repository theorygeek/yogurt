# typed: ignore
# frozen_string_literal: true

RSpec.describe GraphQLClient do
  def declare_query(query_text)
    FakeContainer.declare_query(query_text)
    generator = GraphQLClient::CodeGenerator.new(FakeSchema)
    generator.generate(FakeContainer.declared_queries[0])
    eval(generator.contents)
  end

  it "generates code for basic queries" do
    query_text = <<~'GRAPHQL'
      query SomeQuery {
        viewer {
          login
          createdAt
        }
      }
    GRAPHQL

    allow(FakeExecutor::Instance)
      .to receive(:execute)
      .with(query_text, operation_name: 'SomeQuery', options: nil, variables: nil)
      .and_return({
        'data' => {
          'viewer' => {
            'login' => 'theorygeek',
            'createdAt' => Time.now.iso8601,
          }
        }
      })
    
    declare_query(query_text)
    result = FakeContainer::SomeQuery.execute
    result.pretty_print_inspect
    binding.pry
  end
end
