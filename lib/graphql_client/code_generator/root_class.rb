# typed: strict
# frozen_string_literal: true

module GraphQLClient
  class CodeGenerator
    # Root classes are generated for the root of a GraphQL query.
    class RootClass < T::Struct
      include DefinedClass
      extend T::Sig
      include Utils

      const :name, String
      const :schema, GRAPHQL_SCHEMA
      const :operation_name, String
      const :query_container, QueryContainer::CONTAINER
      const :defined_methods, T::Array[DefinedMethod]

      sig {override.returns(String)}
      def to_ruby
        pretty_print = generate_pretty_print(defined_methods)

        <<~STRING
          class #{name} < GraphQLClient::Query
            extend T::Sig
            include GraphQLClient::QueryResult
            include GraphQLClient::ErrorResult

            self.graphql_schema = #{schema.name}
            self.operation_name = #{operation_name.inspect}
            self.declaration = #{query_container.name}.fetch_query(#{operation_name.inspect})

            sig {params(data: T::Hash[String, T.untyped], errors: T.nilable(T::Array[T::Hash[String, T.untyped]])).void}
            def initialize(data, errors)
              @result = T.let(data, T::Hash[String, T.untyped])
              @errors = T.let(errors, T.nilable(T::Array[T::Hash[String, T.untyped]]))
            end

            sig {override.returns(T::Hash[String, T.untyped])}
            def raw_result
              @result
            end

            sig {override.returns(T.nilable(T::Array[T::Hash[String, T.untyped]]))}
            def errors
              @errors
            end

            #{indent(defined_methods.map(&:to_ruby).join("\n\n"), 1).strip}

            #{indent(pretty_print, 1).strip}
          end
        STRING
      end
    end
  end
end
