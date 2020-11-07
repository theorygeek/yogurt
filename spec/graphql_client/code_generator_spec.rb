# typed: ignore
# frozen_string_literal: true

require 'open3'
RSpec.describe GraphQLClient::CodeGenerator do
  def type_check(code)
    command = %w[bundle exec srb typecheck]
    command.concat(["-e", code])
    out, err, st = Open3.capture3(*command)

    expect(err).to eq "No errors! Great job.\n"
    expect(st).to be_exited
    expect(st).to be_success
  end

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

  # it "handles scalar converters" do 
  #   GraphQLClient.register_scalar(
  #     FakeSchema,
  #     "DateTime",
  #     T.type_alias {Time},
  #     -> (raw_value) {Time.iso8601(raw_value)}
  #   )

  #   query_text = <<~'GRAPHQL'
  #     query SomeQuery {
  #       viewer {
  #         createdAt
  #       }
  #     }
  #   GRAPHQL

  #   FakeContainer.declare_query(query_text)
  #   generator = GraphQLClient::CodeGenerator.new(FakeSchema)
  #   generator.generate(FakeContainer.declared_queries[0])
    
  #   viewer_class = generator.classes["FakeContainer::SomeQuery::Viewer"]
  #   created_at_method = viewer_class.defined_methods.detect {|dm| dm.name == :created_at}
    
  #   expect(created_at_method.signature).to eq "Time"
  #   binding.pry
  # end
end
