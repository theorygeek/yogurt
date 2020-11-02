# typed: strict
# frozen_string_literal: true

require 'graphql'
require 'sorbet-runtime'
require 'zeitwerk'

module GraphQLClient
  extend T::Sig
  
  GRAPHQL_SCHEMA = T.type_alias {T.class_of(GraphQL::Schema)}

  sig {returns(T.nilable(T.class_of(GraphQL::Schema)))}
  def self.default_schema
    @default_schema
  end

  sig {params(schema: T.nilable(T.class_of(GraphQL::Schema))).void}
  def self.default_schema=(schema)
    if schema && schema.name.nil?
      raise ArgumentError, "GraphQL schema must be assigned to a constant"
    end

    @default_schema = T.let(schema, T.nilable(T.class_of(GraphQL::Schema)))
  end
end

loader = Zeitwerk::Loader.new
loader.inflector.inflect({ 
  'graphql_client' => 'GraphQLClient',
  'version' => 'VERSION',
})
loader.push_dir(__dir__)
loader.setup
