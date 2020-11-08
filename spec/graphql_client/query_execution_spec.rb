# typed: ignore
# frozen_string_literal: true

RSpec.describe "QueryResult.execute" do
  def declare_query(query_text)
    GraphQLClient.register_scalar(FakeSchema, "DateTime", GraphQLClient::Converters::Time)

    FakeContainer.declare_query(query_text)
    generator = GraphQLClient::CodeGenerator.new(FakeSchema)
    generator.generate(FakeContainer.declared_queries[0])
    puts(generator.formatted_contents)
    eval(generator.contents)
  end

  it "can execute queries" do
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
      .with(
        query_text,
        operation_name: 'SomeQuery',
        options: nil,
        variables: nil
      )
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
    expect(result.viewer.login).to eq 'theorygeek'
    expect(result.viewer.created_at).to be_a(Time)
    expect(result.codes_of_conduct[0].body).to eq 'Hello World'
  end

  it "can execute queries with variables" do
    GraphQLClient.register_scalar(FakeSchema, "DateTime", GraphQLClient::Converters::Time)
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
    
    completed_at = Time.new(2020, 11, 30, 12, 0, 0).utc
    expect(FakeExecutor::Instance)
      .to receive(:execute)
      .with(
        query_text,
        operation_name: 'SampleMutation',
        options: nil,
        variables: {
          'checkRun' => {
            'headSha' => 'some_sha',
            'name' => 'some name',
            'repositoryId' => 'some_id',
            'actions' => [
              {
                'description' => 'some_description',
                'identifier' => 'some_identifier',
                'label' => 'some_label',
              }
            ],
            'clientMutationId' => nil,
            'completedAt' => nil,
            'conclusion' => nil,
            'detailsUrl' => nil,
            'externalId' => nil,
            'output' => nil,
            'startedAt' => nil,
            'status' => nil,            
          },
          'issueId' => 'some_issue_id',
          'clientMutationId' => 'some_client_mutation_id',
        }
      )
      .and_return({
        'data' => {
          'createCheckRun' => {
            'checkRun' => {
              'completedAt' => completed_at.iso8601,
            }
          },
          'pinIssue' => {
            'clientMutationId' => 'some_client_mutation_id',
          },
        }
      })

    declare_query(query_text)
    result = FakeContainer::SampleMutation.execute(
      issue_id: 'some_issue_id',
      client_mutation_id: 'some_client_mutation_id',
      check_run: FakeSchema::CreateCheckRunInput.new(
        head_sha: 'some_sha',
        name: 'some name',
        repository_id: 'some_id',
        actions: [
          FakeSchema::CheckRunAction.new(
            description: 'some_description',
            identifier: 'some_identifier',
            label: 'some_label',
          )
        ]
      )
    )

    expect(result.create_check_run.check_run.completed_at).to eq(completed_at)
    expect(result.pin_issue.client_mutation_id).to eq 'some_client_mutation_id'
  end
end
