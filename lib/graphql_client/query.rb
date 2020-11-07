# typed: strict
# frozen_string_literal: true

module GraphQLClient
  class Query
    extend T::Sig
    extend T::Helpers
    abstract!

    sig {params(schema: GRAPHQL_SCHEMA).void}
    def self.graphql_schema=(schema)
      @schema = T.let(schema, T.nilable(GRAPHQL_SCHEMA))
    end

    sig {returns(GRAPHQL_SCHEMA)}
    def self.graphql_schema
      T.must(@schema)
    end

    sig {params(operation_name: String).void}
    def self.operation_name=(operation_name)
      @operation_name = T.let(operation_name, T.nilable(String))
    end

    sig {returns(String)}
    def self.operation_name
      T.must(@operation_name)
    end

    sig {params(declaration: QueryDeclaration).void}
    def self.declaration=(declaration)
      @declaration = T.let(declaration, T.nilable(QueryDeclaration))
    end

    sig {returns(QueryDeclaration)}
    def self.declaration
      T.must(@declaration)
    end

    sig {params(result: T::Hash[String, T.untyped]).returns(T.any(T.attached_class, GraphQLClient::ErrorResult))}
    def self.from_result(result)
      data = result['data']
      if data
        new(data, result['errors'])
      else
        GraphQLClient::ErrorResult::OnlyErrors.new(result['errors'])
      end
    end

    sig do
      params(
        variables: T.nilable(T::Hash[String, T.untyped]),
        options: T.untyped
      ).returns(T.any(T.attached_class, GraphQLClient::ErrorResult))
    end
    def self.execute(variables: nil, options: nil)
      execute = GraphQLClient.registered_schemas.fetch(graphql_schema)
      result = execute.execute(
        declaration.query_text,
        operation_name: operation_name,
        variables: variables,
        options: options
      )

      from_result(result)
    end

    sig {params(data: T::Hash[String, T.untyped], errors: T.nilable(T::Hash[String, T.untyped])).void}
    def initialize(data, errors); end
  end
end