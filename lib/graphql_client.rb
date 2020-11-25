# typed: strict
# frozen_string_literal: true

require 'graphql'
require 'sorbet-runtime'
require 'zeitwerk'

module GraphQLClient
  extend T::Sig

  GRAPHQL_SCHEMA = T.type_alias {T.class_of(GraphQL::Schema)}
  SCALAR_TYPE = T.type_alias {T.any(::String, T::Boolean, Numeric)}
  OBJECT_TYPE = T.type_alias {T::Hash[String, T.untyped]}

  sig do
    params(
      schema: GRAPHQL_SCHEMA,
      query: String,
      operation_name: String,
      variables: T.nilable(T::Hash[String, T.untyped]),
      options: T.untyped,
    ).returns(T::Hash[String, T.untyped])
  end
  def self.execute(schema:, query:, operation_name:, variables:, options:)
    execute = GraphQLClient.registered_schemas.fetch(schema)
    execute.execute(
      query,
      operation_name: operation_name,
      variables: variables,
      options: options,
    )
  end

  sig {returns(T.nilable(T.class_of(GraphQL::Schema)))}
  def self.default_schema
    @default_schema
  end

  sig {returns(T::Hash[GRAPHQL_SCHEMA, QueryExecutor])}
  def self.registered_schemas
    @registered_schemas = T.let(@registered_schemas, T.nilable(T::Hash[GRAPHQL_SCHEMA, QueryExecutor]))
    @registered_schemas ||= {}
  end

  sig {params(schema: GRAPHQL_SCHEMA, execute: QueryExecutor, default: T::Boolean).void}
  def self.add_schema(schema, execute, default: true)
    raise ArgumentError, "GraphQL schema must be assigned to a constant" if schema.name.nil?

    registered_schemas[schema] = execute
    @default_schema = T.let(schema, T.nilable(T.class_of(GraphQL::Schema))) if default
  end

  SCALAR_CONVERTER = T.type_alias {T.all(Module, ScalarConverter)}

  sig {params(schema: GRAPHQL_SCHEMA).returns(T::Hash[String, SCALAR_CONVERTER])}
  def self.scalar_converters(schema)
    raise ArgumentError, "GraphQL Schema has not been registered." if !registered_schemas.key?(schema)

    @scalar_converters = T.let(
      @scalar_converters,
      T.nilable(
        T::Hash[
          GRAPHQL_SCHEMA,
          T::Hash[String, SCALAR_CONVERTER]
        ],
      ),
    )

    @scalar_converters ||= Hash.new {|hash, key| hash[key] = {}}
    @scalar_converters[schema]
  end

  sig do
    params(
      schema: GRAPHQL_SCHEMA,
      graphql_type_name: String,
      deserializer: SCALAR_CONVERTER,
    ).void
  end
  def self.register_scalar(schema, graphql_type_name, deserializer)
    raise ArgumentError, "Schema does not contain the type #{graphql_type_name}" if !schema.types.key?(graphql_type_name)

    raise ArgumentError, "ScalarConverters must be assigned to constants" if deserializer.name.nil?

    scalar_converters(schema)[graphql_type_name] = deserializer
  end
end

loader = Zeitwerk::Loader.new
loader.inflector.inflect({
  'graphql_client' => 'GraphQLClient',
  'version' => 'VERSION'
})
loader.push_dir(__dir__)
loader.setup
