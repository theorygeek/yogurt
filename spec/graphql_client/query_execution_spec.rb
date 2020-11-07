# typed: ignore
# frozen_string_literal: true

RSpec.describe "QueryResult.execute" do
  def declare_query(query_text)
    GraphQLClient.register_scalar(FakeSchema, "DateTime", GraphQLClient::Converters::Time)

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

        codesOfConduct {
          id
          body
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
          },

          'codesOfConduct' => [
            {'id' => SecureRandom.hex, 'body' => 'Hello World'},
          ]
        }
      })
    
    declare_query(query_text)
    result = FakeContainer::SomeQuery.execute
    result.pretty_print_inspect
    
    expect(result.viewer.login).to eq 'theorygeek'
    expect(result.viewer.created_at).to be_a(Time)
    expect(result.codes_of_conduct[0].body).to eq 'Hello World'
  end
end
