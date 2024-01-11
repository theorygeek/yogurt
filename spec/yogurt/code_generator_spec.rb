# typed: ignore
# frozen_string_literal: true

RSpec.describe Yogurt::CodeGenerator do
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
    generator = Yogurt::CodeGenerator.new(FakeSchema, GeneratedCode)
    generator.generate(FakeContainer.declared_queries[0])

    classes = generator.classes
    expect(classes).to include '::FakeContainer::SomeQuery'
    expect(classes).to include '::FakeContainer::SomeQuery::Viewer'

    query_class = generator.classes["::FakeContainer::SomeQuery"]
    expect(query_class).to be_a Yogurt::CodeGenerator::RootClass
    expect(query_class.name).to eq "::FakeContainer::SomeQuery"
    expect(query_class.operation_name).to eq "SomeQuery"
    expect(query_class.defined_methods.map(&:name)).to eq [:viewer]
    expect(query_class.graphql_type.graphql_name).to eq "Query"
    expect(query_class.to_ruby).to include "def viewer"
    expect(query_class.to_ruby).to include "def pretty_print"
    expect(query_class.to_ruby).to include "def self.execute"

    viewer_class = generator.classes["::FakeContainer::SomeQuery::Viewer"]
    expect(viewer_class).to be_a Yogurt::CodeGenerator::LeafClass
    expect(viewer_class.name).to eq "::FakeContainer::SomeQuery::Viewer"
    expect(viewer_class.graphql_type.graphql_name).to eq "User"
    expect(viewer_class.to_ruby).to include "def login"
    expect(viewer_class.to_ruby).to include "def created_at"
    expect(viewer_class.defined_methods.map(&:name)).to match_array(%i[login created_at])

    login_method = viewer_class.defined_methods.detect {|dm| dm.name == :login}
    expect(login_method.signature).to eq "String"
    expect(login_method.body).to eq 'T.cast(raw_result["login"], String)'

    created_at_method = viewer_class.defined_methods.detect {|dm| dm.name == :created_at}
    expect(created_at_method.signature).to eq "T.any(Numeric, String, T::Boolean)"
    expect(created_at_method.body).to eq 'T.cast(raw_result["createdAt"], T.any(Numeric, String, T::Boolean))'

    # Generated code should pass sorbet typechecking
    type_check(generator.contents)
  end

  it "handles scalar converters" do
    Yogurt.register_scalar(FakeSchema, "DateTime", Yogurt::Converters::Time)

    query_text = <<~'GRAPHQL'
      query SomeQuery {
        viewer {
          createdAt
        }
      }
    GRAPHQL

    FakeContainer.declare_query(query_text)
    generator = Yogurt::CodeGenerator.new(FakeSchema, GeneratedCode)
    generator.generate(FakeContainer.declared_queries[0])

    viewer_class = generator.classes["::FakeContainer::SomeQuery::Viewer"]
    created_at_method = viewer_class.defined_methods.detect {|dm| dm.name == :created_at}

    expect(created_at_method.signature).to eq "Time"
    expect(created_at_method.body).to eq 'Yogurt::Converters::Time.deserialize(raw_result["createdAt"])'
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
    generator = Yogurt::CodeGenerator.new(FakeSchema, GeneratedCode)
    generator.generate(FakeContainer.declared_queries[0])

    query_class = generator.classes["::FakeContainer::SomeQuery"]
    codes_of_conduct = query_class.defined_methods.detect {|dm| dm.name == :codes_of_conduct}
    expect(codes_of_conduct).to_not be_nil
    expect(codes_of_conduct.signature).to eq "T.nilable(T::Array[T.nilable(::FakeContainer::SomeQuery::CodesOfConduct)])"

    subclass = generator.classes["::FakeContainer::SomeQuery::CodesOfConduct"]
    expect(subclass.graphql_type.graphql_name).to eq "CodeOfConduct"

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
    generator = Yogurt::CodeGenerator.new(FakeSchema, GeneratedCode)
    generator.generate(FakeContainer.declared_queries[0])

    check_run_input = generator.classes['::FakeSchema::CreateCheckRunInput']
    expect(check_run_input).to_not be_nil
    expect(check_run_input).to be_a Yogurt::CodeGenerator::InputClass
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

    expect(action_argument.signature).to eq "T.nilable(T::Array[::FakeSchema::CheckRunAction])"
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
    generator = Yogurt::CodeGenerator.new(FakeSchema, GeneratedCode)
    generator.generate(FakeContainer.declared_queries[0])

    query = generator.classes["::FakeContainer::AliasedQuery"]
    me_method = query.defined_methods.detect {|dm| dm.name == :me}
    expect(me_method).to_not be_nil
    expect(me_method.signature).to eq "::FakeContainer::AliasedQuery::MeViewer"

    me_class = generator.classes["::FakeContainer::AliasedQuery::MeViewer"]
    expect(me_class.defined_methods.map(&:name)).to eq [:type]
    expect(me_class.graphql_type.graphql_name).to eq "User"

    type_check(generator.contents)
  end

  describe '#content_files' do
    it "generates the right output files" do
      Yogurt.register_scalar(FakeSchema, "DateTime", Yogurt::Converters::Time)

      FakeContainer.declare_query(<<~'GRAPHQL')
        query SomeQuery {
          viewer {
            createdAt
          }
        }
      GRAPHQL

      FakeContainer.declare_query(<<~'GRAPHQL')
        query AliasedQuery {
          me: viewer {
            type: __typename
          }
        }
      GRAPHQL

      FakeContainer.declare_query(<<~'GRAPHQL')
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

      generator = Yogurt::CodeGenerator.new(FakeSchema, GeneratedCode)
      FakeContainer.declared_queries.each {|declaration| generator.generate(declaration)}
      expect(generator.content_files.map(&:constant_name).sort).to eq([
        "::FakeContainer::AliasedQuery",
        "::FakeContainer::AliasedQuery::MeViewer",
        "::GeneratedCode::CheckConclusionState",
        "::FakeSchema::CheckRunAction",
        "::GeneratedCode::CheckAnnotationLevel",
        "::FakeSchema::CheckAnnotationRange",
        "::FakeSchema::CheckAnnotationData",
        "::FakeSchema::CheckRunOutputImage",
        "::FakeSchema::CheckRunOutput",
        "::GeneratedCode::RequestableCheckStatusState",
        "::FakeSchema::CreateCheckRunInput",
        "::FakeContainer::SampleMutation",
        "::FakeContainer::SampleMutation::CreateCheckRun",
        "::FakeContainer::SampleMutation::CreateCheckRun::CheckRun",
        "::FakeContainer::SampleMutation::PinIssue",
        "::FakeContainer::SomeQuery",
        "::FakeContainer::SomeQuery::Viewer"
      ].sort)
    end
  end

  describe "fragments" do
    it "uses the typename retrieved from the server when querying interfaces" do
      query_text = <<~'GRAPHQL'
        query NodeQuery {
          node(id: "abc") {
            __typename
          }
        }
      GRAPHQL

      FakeContainer.declare_query(query_text)
      generator = Yogurt::CodeGenerator.new(FakeSchema, GeneratedCode)
      generator.generate(FakeContainer.declared_queries[0])

      node_class = generator.classes["::FakeContainer::NodeQuery::Node"]
      expect(node_class.graphql_type.graphql_name).to eq "Node"
      type_check(generator.contents)
    end

    it "generates a composite type if multiple return types are possible" do
      query_text = <<~'GRAPHQL'
        query NodeQuery {
          node(id: "abc") {
            __typename
            ... on Project {
              state
            }
            ... on ProjectCard {
              state
            }
            ... on PullRequest {
              state
            }
          }
        }
      GRAPHQL

      FakeContainer.declare_query(query_text)
      generator = Yogurt::CodeGenerator.new(FakeSchema, GeneratedCode)
      generator.generate(FakeContainer.declared_queries[0])

      node_class = generator.classes["::FakeContainer::NodeQuery::Node"]
      state_method = node_class.defined_methods.detect {|dm| dm.name == :state}
      expect(state_method).to_not be_nil
      expect(state_method.signature).to start_with "T.nilable("

      expect(state_method.branches).to match_array([
        Yogurt::CodeGenerator::FieldAccessMethod::FragmentBranch.new(
          typenames: Set.new(["Project"]),
          expression: '::GeneratedCode::ProjectState.deserialize(raw_result["state"])',
        ),
        Yogurt::CodeGenerator::FieldAccessMethod::FragmentBranch.new(
          typenames: Set.new(["ProjectCard"]),
          expression: <<~STRING.strip,
            return if raw_result["state"].nil?
            ::GeneratedCode::ProjectCardState.deserialize(raw_result["state"])
          STRING
        ),
        Yogurt::CodeGenerator::FieldAccessMethod::FragmentBranch.new(
          typenames: Set.new(["PullRequest"]),
          expression: '::GeneratedCode::PullRequestState.deserialize(raw_result["state"])',
        )
      ])

      expect(state_method.body).to include 'when "Project"'
      expect(state_method.body).to include 'when "ProjectCard"'
      expect(state_method.body).to include 'when "PullRequest"'
      type_check(generator.contents)
    end

    it "handles double-nested fragments" do
      query_text = <<~'GRAPHQL'
        query NodeQuery {
          node(id: "abc") {
            __typename
            ... on User {
              ... on Actor {
                login
              }
            }
          }
        }
      GRAPHQL

      FakeContainer.declare_query(query_text)
      generator = Yogurt::CodeGenerator.new(FakeSchema, GeneratedCode)
      generator.generate(FakeContainer.declared_queries[0])

      node_class = generator.classes["::FakeContainer::NodeQuery::Node"]
      login_method = node_class.defined_methods.detect {|dm| dm.name == :login}
      expect(login_method.body).to include 'return unless type == "User"'
      expect(login_method.body).to_not include 'type == "Bot"'
      type_check(generator.contents)
    end

    it "marks a field nullable when it is impossible to access" do
      query_text = <<~'GRAPHQL'
        query ViewerQuery {
          viewer {
            ... on Node {
              ... on Commit {
                id
              }
            }
          }
        }
      GRAPHQL

      FakeContainer.declare_query(query_text)
      generator = Yogurt::CodeGenerator.new(FakeSchema, GeneratedCode)
      generator.generate(FakeContainer.declared_queries[0])

      viewer_class = generator.classes["::FakeContainer::ViewerQuery::Viewer"]
      id_method = viewer_class.defined_methods.detect {|dm| dm.name == :id}
      expect(id_method.signature).to eq "NilClass"
      expect(id_method.body).to end_with "nil\n"
      type_check(generator.contents)
    end

    it "handles nested fragments that are used for type detection" do
      query_text = <<~'GRAPHQL'
        query NodeQuery {
          node(id: "foobar") {
            __typename
            ... on Actor {
              ... on Bot {
                id
              }
              ... on User {
                id
              }
            }
          }
        }
      GRAPHQL

      FakeContainer.declare_query(query_text)
      generator = Yogurt::CodeGenerator.new(FakeSchema, GeneratedCode)
      generator.generate(FakeContainer.declared_queries[0])

      node_class = generator.classes["::FakeContainer::NodeQuery::Node"]
      id_method = node_class.defined_methods.detect {|dm| dm.name == :id}
      expect(id_method.signature).to start_with "T.nilable"
      expect(id_method.body).to include 'return unless type == "Bot" || type == "User"'
      type_check(generator.contents)
    end

    it "handles multiple paths to the same field" do
      query_text = <<~'GRAPHQL'
        query NodeQuery {
          viewer {
            id
            ... on Node {
              ... on Actor {
                ... on Bot {
                  id
                }
                ... on User {
                  id
                }
              }
              ... on Commit {
                id
              }
            }
          }
        }
      GRAPHQL

      FakeContainer.declare_query(query_text)
      generator = Yogurt::CodeGenerator.new(FakeSchema, GeneratedCode)
      generator.generate(FakeContainer.declared_queries[0])

      viewer_class = generator.classes["::FakeContainer::NodeQuery::Viewer"]
      id_method = viewer_class.defined_methods.detect {|dm| dm.name == :id}
      expect(id_method.signature).to_not include "T.nilable"
      expect(id_method.body).to_not include "__typename"
      type_check(generator.contents)
    end

    it "does not mark a field nullable when a fragment is used against an object type" do
      query_text = <<~'GRAPHQL'
        query NodeQuery {
          viewer {
            ... on Node {
              id
            }
          }
        }
      GRAPHQL

      FakeContainer.declare_query(query_text)
      generator = Yogurt::CodeGenerator.new(FakeSchema, GeneratedCode)
      generator.generate(FakeContainer.declared_queries[0])

      viewer_class = generator.classes["::FakeContainer::NodeQuery::Viewer"]
      id_method = viewer_class.defined_methods.detect {|dm| dm.name == :id}
      expect(id_method.signature).to_not include "T.nilable"
      type_check(generator.contents)
    end

    it "generates composite types when multiple fields are given the same alias" do
      query_text = <<~'GRAPHQL'
        query NodeQuery($id: ID!) {
          node(id: $id) {
            __typename
            ... on CommitComment {
              field: viewerCannotUpdateReasons
            }
            ... on CommitCommentThread {
              field: position
            }
            ... on CrossReferencedEvent {
              field: actor {
                __typename
                login
              }
            }
            ... on AddedToProjectEvent {
              field: projectCard {
                createdAt
                note
              }
            }
          }
        }
      GRAPHQL

      FakeContainer.declare_query(query_text)
      generator = Yogurt::CodeGenerator.new(FakeSchema, GeneratedCode)
      generator.generate(FakeContainer.declared_queries[0])

      node_class = generator.classes["::FakeContainer::NodeQuery::Node"]
      field_method = node_class.defined_methods.detect {|dm| dm.name == :field}
      expect(field_method).to_not be_nil
      expect(field_method.signature).to eq "T.nilable(T.any(::FakeContainer::NodeQuery::Node::FieldActor, ::FakeContainer::NodeQuery::Node::FieldProjectCard, Integer, T::Array[::GeneratedCode::CommentCannotUpdateReason]))"

      expect(field_method.branches).to match_array([
        Yogurt::CodeGenerator::FieldAccessMethod::FragmentBranch.new(
          typenames: Set.new(["CommitComment"]),
          expression: <<~STRING.strip,
            raw_result["field"].map do |raw_value|
              ::GeneratedCode::CommentCannotUpdateReason.deserialize(raw_value)
            end
          STRING
        ),
        Yogurt::CodeGenerator::FieldAccessMethod::FragmentBranch.new(
          typenames: Set.new(["CommitCommentThread"]),
          expression: <<~STRING.strip,
            return if raw_result["field"].nil?
            T.cast(raw_result["field"], Integer)
          STRING
        ),
        Yogurt::CodeGenerator::FieldAccessMethod::FragmentBranch.new(
          typenames: Set.new(["CrossReferencedEvent"]),
          expression: <<~STRING.strip,
            return if raw_result["field"].nil?
            ::FakeContainer::NodeQuery::Node::FieldActor.new(raw_result["field"])
          STRING
        ),
        Yogurt::CodeGenerator::FieldAccessMethod::FragmentBranch.new(
          typenames: Set.new(["AddedToProjectEvent"]),
          expression: <<~STRING.strip,
            return if raw_result["field"].nil?
            ::FakeContainer::NodeQuery::Node::FieldProjectCard.new(raw_result["field"])
          STRING
        )
      ])

      type_check(generator.contents)
    end

    it "handles the same field expanded inside of multiple fragments" do
      query_text = <<~'GRAPHQL'
        query NodeQuery($id: ID!) {
          node(id: $id) {
            __typename
            ... on AddedToProjectEvent {
              projectCard {
                creator {
                  __typename
                  ... on Node {
                    ... on Commit {
                      url
                    }
                  }
                }
              }
            }

            ... on AddedToProjectEvent {
              projectCard {
                createdAt
                note
                creator {
                  __typename
                  url
                }
              }
            }
          }
        }
      GRAPHQL

      FakeContainer.declare_query(query_text)
      generator = Yogurt::CodeGenerator.new(FakeSchema, GeneratedCode)
      generator.generate(FakeContainer.declared_queries[0])

      project_card_class = generator.classes["::FakeContainer::NodeQuery::Node::ProjectCard"]

      # It should have methods for all of the fragments that are spread
      expect(project_card_class.defined_methods.map(&:name)).to match_array(%i[creator created_at note])

      # It should have paths to the `id` of the `creator` that match each of the fragments
      project_card_creator_class = generator.classes["::FakeContainer::NodeQuery::Node::ProjectCard::Creator"]
      url_method = project_card_creator_class.defined_methods.detect {|dm| dm.name == :url}
      expect(url_method).to_not be_nil
      expect(url_method.field_access_paths.map(&:fragment_types)).to match_array([
        %w[Actor Node Commit],
        ["Actor"]
      ])

      # The presence of the extra fragment should remove the impossible access for the `url` field
      expect(url_method.field_access_is_impossible?).to eq false
      expect(url_method.field_access_is_guaranteed?).to eq true
      expect(url_method.body).to eq "T.cast(raw_result[\"url\"], #{Yogurt::SCALAR_TYPE.name})"
      expect(url_method.signature).to eq Yogurt::SCALAR_TYPE.name
      type_check(generator.contents)
    end
  end
end
