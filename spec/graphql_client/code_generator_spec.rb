# typed: ignore
# frozen_string_literal: true

RSpec.describe GraphQLClient::CodeGenerator do
  let(:fake_container) do
    Module.new do
      extend GraphQLClient::QueryContainer
    end
  end

  before do
    GraphQLClient.load_schema(path: File.expand_path('../github_schema.graphql', __dir__))
    stub_const("FakeContainer", fake_container)
  end

  it "generates code for basic queries" do
    query_text = <<~'GRAPHQL'
      query {
        viewer {
          login
          createdAt
        }
      }
    GRAPHQL
    
    FakeContainer.declare_query(:Viewer, query_text)

    
  end
end
