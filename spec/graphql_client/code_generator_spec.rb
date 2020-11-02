# typed: ignore
# frozen_string_literal: true

RSpec.describe GraphQLClient::CodeGenerator do
  let(:fake_container) do
    Module.new do
      extend GraphQLClient::QueryContainer
    end
  end

  before do
    schema = File.read(File.expand_path("../github_schema.graphql", __dir__))
    fake_schema = GraphQL::Schema.from_definition(schema)
    stub_const("FakeSchema", fake_schema)
    
    GraphQLClient.default_schema = fake_schema
    stub_const("FakeContainer", fake_container)
  end

  it "generates code for basic queries" do
    query_text = <<~'GRAPHQL'
      query SomeQuery {
        viewer {
          login
          createdAt
          ...v
        }
      }

      fragment v on User {
        login
      }
    GRAPHQL
    
    FakeContainer.declare_query(:Viewer, query_text)
    generator = GraphQLClient::CodeGenerator.new(FakeSchema)
    generator.generate(FakeContainer.declared_queries[0])

    binding.pry
  end
end
