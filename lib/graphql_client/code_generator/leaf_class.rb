# typed: strict
# frozen_string_literal: true

module GraphQLClient
  class CodeGenerator
    # Leaf classes are generated for the inner types of query results.
    class LeafClass < T::Struct
      include DefinedClass
      extend T::Sig
      include Utils

      const :name, String
      const :schema, GRAPHQL_SCHEMA
      const :defined_methods, T::Array[DefinedMethod]
      const :dependencies, T::Array[String]
      const :graphql_type, T.untyped # rubocop:disable Sorbet/ForbidUntypedStructProps

      sig {override.returns(String)}
      def to_ruby
        pretty_print = generate_pretty_print(defined_methods)

        dynamic_methods = <<~STRING.strip
          #{defined_methods.map(&:to_ruby).join("\n")}
          #{pretty_print}
        STRING

        <<~STRING
          class #{name}
            extend T::Sig
            include GraphQLClient::QueryResult

            #{indent(possible_types_constant(schema, graphql_type), 1).strip}

            sig {params(result: GraphQLClient::OBJECT_TYPE).void}
            def initialize(result)
              @result = T.let(result, GraphQLClient::OBJECT_TYPE)
            end

            sig {override.returns(GraphQLClient::OBJECT_TYPE)}
            def raw_result
              @result
            end

            #{indent(typename_method(schema, graphql_type), 1).strip}

            #{indent(dynamic_methods, 1).strip}
          end
        STRING
      end
    end
  end
end
