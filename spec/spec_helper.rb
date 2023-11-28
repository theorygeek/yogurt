# typed: strict
# frozen_string_literal: true

require "bundler/setup"
Bundler.require(:default, :development)
require 'yogurt'
require_relative 'support/type_check'
require_relative 'support/fake_executor'

module GeneratedCode
  # containing module for generated code
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include(TypeCheck)
  config.before(:each) do |_each|
    fake_schema = File.read(File.expand_path("./github_schema.graphql", __dir__))
    stub_const("FakeSchema", GraphQL::Schema.from_definition(fake_schema))

    fake_container = Module.new do
      extend Yogurt::QueryContainer
    end

    stub_const("FakeContainer", fake_container)
    Yogurt.add_schema(FakeSchema, FakeExecutor::Instance)
  end

  config.after(:each) do |_each|
    Yogurt.instance_variables.each do |variable|
      Yogurt.remove_instance_variable(variable)
    end
  end
end
