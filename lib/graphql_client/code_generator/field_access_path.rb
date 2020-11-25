# typed: strict
# frozen_string_literal: true

module GraphQLClient
  class CodeGenerator
    class FieldAccessPath < T::Struct
      extend T::Sig
      extend Utils
      include Utils
      include Memoize

      # Name of the method
      const :name, Symbol

      # Sorbet signature for the value of the field
      const :signature, String

      # Expression for converting the value of the field
      const :expression, String

      # GraphQL schema for the query that this FieldAccessPath was derived from
      const :schema, GRAPHQL_SCHEMA

      # The types of all of the fragments leading to this field
      const :fragment_types, T::Array[String]

      sig {returns(T.self_type)}
      def freeze
        compatible_object_types
        fragment_types.each(&:freeze)
        fragment_types.freeze
        expression.freeze
        signature.freeze
        super
        self
      end

      # This field access path will only be evaluated if the object in the query
      # is one of the objects in this set.
      sig {returns(T::Set[String])}
      def compatible_object_types
        memoize_as(:compatible_object_types) do
          result = schema.possible_types(schema.types[fragment_types.fetch(0)]).to_set

          if fragment_types.size > 1
            T.must(fragment_types[1..-1]).each do |next_type|
              result = result.intersection(schema.possible_types(schema.types[next_type]))
            end
          end

          result.map(&:graphql_name).to_set.freeze
        end
      end
    end
  end
end
