# typed: ignore
# frozen_string_literal: true

RSpec.describe GraphQLClient::QueryContainer do
  let(:fake_container) do
    Module.new do
      extend GraphQLClient::QueryContainer
    end
  end

  before do
    fake_schema = GraphQL::Schema.from_definition(schema)
    stub_const("FakeSchema", fake_schema)
    
    GraphQLClient.default_schema = fake_schema
    stub_const("FakeContainer", fake_container)
  end

  it "can declare queries" do
    query_text = <<~'GRAPHQL'
      query Foobar {
        viewer {
          login
          createdAt
        }
      }
    GRAPHQL
    
    FakeContainer.declare_query(:Viewer, query_text)

    declaration = FakeContainer.declared_queries[0]
    expect(declaration).to_not be nil
    expect(declaration.container).to eq FakeContainer
    expect(declaration.constant_name).to eq :Viewer
    expect(declaration.query_text).to eq query_text
  end

  it "raises an error if the query is invalid" do
    query_text = <<~'GRAPHQL'
      query Foobar {
        viewer {
          foobarFakeField
        }
      }
    GRAPHQL
    
    expect {FakeContainer.declare_query(:Viewer, query_text)}
      .to raise_error(GraphQLClient::ValidationError, /foobarFakeField/)
  end

  it "raises an error if the query doesn't provide names for the operations" do
    query_text = <<~'GRAPHQL'
      query {
        viewer {
          login
        }
      }
    GRAPHQL
    
    expect {FakeContainer.declare_query(:Viewer, query_text)}
      .to raise_error(GraphQLClient::ValidationError, /name for each of the operations/)
  end
end
