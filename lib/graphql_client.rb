# typed: strict
# frozen_string_literal: true

require 'graphql'
require 'sorbet-runtime'
require 'zeitwerk'

module GraphQLClient
  extend T::Sig

  sig {returns(T.nilable(T.class_of(GraphQL::Schema)))}
  def self.default_schema
    @default_schema
  end

  sig {params(schema: T.nilable(T.class_of(GraphQL::Schema))).void}
  def self.default_schema=(schema)
    @default_schema = T.let(schema, T.nilable(T.class_of(GraphQL::Schema)))
  end

  # Loads the schema and sets it as the default.
  sig do
    params(
      schema: T.nilable(String),
      path: T.nilable(String)
    ).void
  end
  def self.load_schema(schema: nil, path: nil)
    if path
      schema = File.read(path)
    end

    if schema.nil?
      raise ArgumentError, "You must provide either `schema:` or `path:` to GraphQLClient.load_schema"
    end

    self.default_schema = GraphQL::Schema.from_definition(schema)
  end
end

loader = Zeitwerk::Loader.new
loader.inflector.inflect({ 
  'graphql_client' => 'GraphQLClient',
  'version' => 'VERSION',
})
loader.push_dir(__dir__)
loader.setup
