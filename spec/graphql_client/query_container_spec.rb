# typed: ignore
# frozen_string_literal: true

RSpec.describe GraphQLClient::QueryContainer do
  let(:fake_container) do
    Module.new do
      extend GraphQLClient::QueryContainer
    end
  end

  before do
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
end
