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
      const :defined_methods, T::Array[DefinedMethod]
      const :dependencies, T::Array[String]
      const :typename, T.nilable(String)

      sig {override.returns(String)}
      def to_ruby
        pretty_print = generate_pretty_print(defined_methods)

        typename_impl = if typename
          typename.inspect
        else
          "raw_result['__typename']"
        end

        dynamic_methods = <<~STRING.strip
          #{defined_methods.map(&:to_ruby).join("\n")}
          #{pretty_print}
        STRING

        <<~STRING
          class #{name}
            extend T::Sig
            include GraphQLClient::QueryResult

            sig {params(result: GraphQLClient::OBJECT_TYPE).void}
            def initialize(result)
              @result = T.let(result, GraphQLClient::OBJECT_TYPE)
            end

            sig {override.returns(GraphQLClient::OBJECT_TYPE)}
            def raw_result
              @result
            end

            sig {override.returns(String)}
            def __typename
              #{typename_impl}
            end

            #{indent(dynamic_methods, 1).strip}
          end
        STRING
      end
    end
  end
end
