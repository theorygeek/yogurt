# typed: ignore
# frozen_string_literal: true

RSpec.describe GraphQLClient::CodeGenerator do
  it "generates code for basic queries" do
    query_text = <<~'GRAPHQL'
      query SomeQuery {
        viewer {
          login
          createdAt
        }
      }
    GRAPHQL

    FakeContainer.declare_query(query_text)
    generator = GraphQLClient::CodeGenerator.new(FakeSchema)
    generator.generate(FakeContainer.declared_queries[0])

    classes = generator.classes
    expect(classes).to include 'FakeContainer::SomeQuery'
    expect(classes).to include 'FakeContainer::SomeQuery::Viewer'

    query_class = generator.classes["FakeContainer::SomeQuery"]
    expect(query_class).to be_a GraphQLClient::CodeGenerator::RootClass
    expect(query_class.name).to eq "FakeContainer::SomeQuery"
    expect(query_class.operation_name).to eq "SomeQuery"
    expect(query_class.defined_methods.map(&:name)).to eq [:viewer]

    viewer_class = generator.classes["FakeContainer::SomeQuery::Viewer"]
    expect(viewer_class).to be_a GraphQLClient::CodeGenerator::LeafClass
    expect(viewer_class.name).to eq "FakeContainer::SomeQuery::Viewer"
    expect(viewer_class.defined_methods.map(&:name)).to match_array([:login, :created_at])

    login_method = viewer_class.defined_methods.detect {|dm| dm.name == :login}
    expect(login_method.signature).to eq "String"
    expect(login_method.body).to eq 'T.let(raw_result["login"], String)'

    created_at_method = viewer_class.defined_methods.detect {|dm| dm.name == :created_at}
    expect(created_at_method.signature).to eq "T.any(Numeric, String, T::Boolean)"
    expect(created_at_method.body).to eq 'T.let(raw_result["createdAt"], T.any(Numeric, String, T::Boolean))'

    # Generated code should pass sorbet typechecking
    type_check(generator.contents)
  end

  it "handles scalar converters" do
    GraphQLClient.register_scalar(FakeSchema, "DateTime", GraphQLClient::Converters::Time)

    query_text = <<~'GRAPHQL'
      query SomeQuery {
        viewer {
          createdAt
        }
      }
    GRAPHQL

    FakeContainer.declare_query(query_text)
    generator = GraphQLClient::CodeGenerator.new(FakeSchema)
    generator.generate(FakeContainer.declared_queries[0])
    
    viewer_class = generator.classes["FakeContainer::SomeQuery::Viewer"]
    created_at_method = viewer_class.defined_methods.detect {|dm| dm.name == :created_at}
    
    expect(created_at_method.signature).to eq "Time"
    expect(created_at_method.body).to eq 'GraphQLClient::Converters::Time.deserialize(raw_result["createdAt"])'
    type_check(generator.contents)
  end

  it "handles arrays and nullable values" do
    query_text = <<~'GRAPHQL'
      query SomeQuery {
        codesOfConduct {
          body
          id
          key
          name
          resourcePath
          url
        }
      }
    GRAPHQL

    FakeContainer.declare_query(query_text)
    generator = GraphQLClient::CodeGenerator.new(FakeSchema)
    generator.generate(FakeContainer.declared_queries[0])

    query_class = generator.classes["FakeContainer::SomeQuery"]
    codes_of_conduct = query_class.defined_methods.detect {|dm| dm.name == :codes_of_conduct}
    expect(codes_of_conduct).to_not be_nil
    expect(codes_of_conduct.signature).to eq "T.nilable(T::Array[T.nilable(FakeContainer::SomeQuery::CodesOfConduct)])"

    subclass = generator.classes["FakeContainer::SomeQuery::CodesOfConduct"]
    url_method = subclass.defined_methods.detect {|dm| dm.name == :url}
    expect(url_method).to_not be_nil
    expect(url_method.signature).to eq "T.nilable(T.any(Numeric, String, T::Boolean))"

    type_check(generator.contents)
  end

  it "handles variables" do
    query_text = <<~'GRAPHQL'
      mutation SampleMutation($checkRun: CreateCheckRunInput!, $issueId: ID!, $clientMutationId: String) {
        createCheckRun(input: $checkRun) {
          checkRun {
            completedAt
          }
        }

        pinIssue(input: {clientMutationId: $clientMutationId, issueId: $issueId}) {
          clientMutationId
        }
      }
    GRAPHQL

    FakeContainer.declare_query(query_text)
    generator = GraphQLClient::CodeGenerator.new(FakeSchema)
    generator.generate(FakeContainer.declared_queries[0])

    check_run_input = generator.classes['FakeSchema::CreateCheckRunInput']
    expect(check_run_input).to_not be_nil
    expect(check_run_input).to be_a GraphQLClient::CodeGenerator::InputClass
    expect(check_run_input.arguments.map(&:name)).to match_array(%i[
      actions
      client_mutation_id
      completed_at
      conclusion
      details_url
      external_id
      head_sha
      name
      output
      repository_id
      started_at
      status
    ])

    expect(check_run_input.arguments.map(&:graphql_name)).to match_array(%w[
      actions
      clientMutationId
      completedAt
      conclusion
      detailsUrl
      externalId
      headSha
      name
      output
      repositoryId
      startedAt
      status
    ])
    
    action_argument = check_run_input.arguments.detect {|dm| dm.name == :actions}
    expect(action_argument.serializer).to eq <<~STRING.strip
      if actions
        actions.map do |actions1|
          actions1.serialize
        end
      end
    STRING

    expect(action_argument.signature).to eq "T.nilable(T::Array[FakeSchema::CheckRunAction])"
    type_check(generator.contents)
  end

  it "handles aliases" do
    query_text = <<~'GRAPHQL'
      query AliasedQuery {
        me: viewer {
          type: __typename
        }
      }
    GRAPHQL

    FakeContainer.declare_query(query_text)
    generator = GraphQLClient::CodeGenerator.new(FakeSchema)
    generator.generate(FakeContainer.declared_queries[0])

    query = generator.classes["FakeContainer::AliasedQuery"]
    me_method = query.defined_methods.detect {|dm| dm.name == :me}
    expect(me_method).to_not be_nil
    expect(me_method.signature).to eq "FakeContainer::AliasedQuery::Me"

    me_class = generator.classes["FakeContainer::AliasedQuery::Me"]
    expect(me_class.defined_methods.map(&:name)).to eq [:type]

    type_check(generator.contents)
  end
end
