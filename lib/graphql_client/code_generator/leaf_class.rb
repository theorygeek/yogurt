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

      sig {override.returns(String)}
      def to_ruby
        pretty_print = generate_pretty_print(defined_methods)

        <<~STRING
          class #{name}
            extend T::Sig
            include GraphQLClient::QueryResult

            sig {params(result: T::Hash[String, T.untyped]).void}
            def initialize(result)
              @result = T.let(result, T::Hash[String, T.untyped])
            end

            sig {override.returns(T::Hash[String, T.untyped])}
            def raw_result
              @result
            end

            #{indent(defined_methods.map(&:to_ruby).join("\n"), 1).strip}

            #{indent(pretty_print, 1).strip}
          end
        STRING
      end
    end
  end
end
