# typed: ignore
# frozen_string_literal: true

RSpec.describe GraphQLClient::QueryContainer do
  let(:fake_container) do
    Module.new do
      extend GraphQLClient::QueryContainer
    end
  end

  before do
    GraphQLClient.load_schema(path: File.expand_path('../github_schema.graphql', __dir__))
    stub_const("FakeContainer", fake_container)
  end

  it "can declare queries" do
    query_text = <<~'GRAPHQL'
      query {
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
      query {
        viewer {
          foobarFakeField
        }
      }
    GRAPHQL
    
    expect {FakeContainer.declare_query(:Viewer, query_text)}.to raise_error(GraphQLClient::ValidationError)
  end
end
