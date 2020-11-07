# typed: strict
# frozen_string_literal: true

require "bundler/setup"
Bundler.require(:default, :development)
require "graphql_client"
require_relative 'support/fake_executor'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:each) do |each|
    fake_schema = File.read(File.expand_path("./github_schema.graphql", __dir__))
    stub_const("FakeSchema", GraphQL::Schema.from_definition(fake_schema))

    fake_container = Module.new do
      extend GraphQLClient::QueryContainer
    end

    stub_const("FakeContainer", fake_container)
    GraphQLClient.add_schema(FakeSchema, FakeExecutor::Instance)
  end

  config.after(:each) do |each|
    GraphQLClient.instance_variables.each do |variable|
      GraphQLClient.remove_instance_variable(variable)
    end
  end
end
