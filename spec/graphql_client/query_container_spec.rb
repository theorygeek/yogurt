# typed: ignore
# frozen_string_literal: true

RSpec.describe GraphQLClient::QueryContainer do
  it "can declare queries" do
    query_text = <<~'GRAPHQL'
      query Foobar {
        viewer {
          login
          createdAt
        }
      }
    GRAPHQL

    FakeContainer.declare_query(query_text)

    declaration = FakeContainer.declared_queries[0]
    expect(declaration).to_not be nil
    expect(declaration.container).to eq FakeContainer
    expect(declaration.operations).to eq ['Foobar']
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

    expect {FakeContainer.declare_query(query_text)}
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

    expect {FakeContainer.declare_query(query_text)}
      .to raise_error(GraphQLClient::ValidationError, /name for each of the operations/)
  end

  describe 'InterfacesAndUnionsHaveTypename' do
    it "raises an error if a query against an interface type doesn't include __typename" do
      query_text = <<~'GRAPHQL'
        query Foobar {
          node(id: "foobar") {
            id
          }
        }
      GRAPHQL

      expect {FakeContainer.declare_query(query_text)}
        .to raise_error(GraphQLClient::ValidationError, /__typename/)
    end

    it "raises an error if the __typename field is aliased" do
      query_text = <<~'GRAPHQL'
        query Foobar {
          node(id: "foobar") {
            id
            type: __typename
          }
        }
      GRAPHQL

      expect {FakeContainer.declare_query(query_text)}
        .to raise_error(GraphQLClient::ValidationError, /__typename/)
    end

    it "doesn't raise an error if the interface includes __typename" do
      query_text = <<~'GRAPHQL'
        query Foobar {
          node(id: "foobar") {
            id
            __typename
          }
        }
      GRAPHQL

      expect {FakeContainer.declare_query(query_text)}.to_not raise_error
    end

    it "raises an error even if there is an inline fragment spread that includes __typename" do
      query_text = <<~'GRAPHQL'
        query Foobar {
          node(id: "foobar") {
            id
            ... on Node {
              __typename
            }
          }
        }
      GRAPHQL

      expect {FakeContainer.declare_query(query_text)}
        .to raise_error(GraphQLClient::ValidationError, /__typename/)
    end

    it "raises an error even if there is a named fragment spread that includes __typename" do
      query_text = <<~'GRAPHQL'
        query Foobar {
          node(id: "foobar") {
            id
            ...node
          }
        }

        fragment node on Node {
          __typename
        }
      GRAPHQL

      expect {FakeContainer.declare_query(query_text)}
        .to raise_error(GraphQLClient::ValidationError, /__typename/)
    end
  end
end
