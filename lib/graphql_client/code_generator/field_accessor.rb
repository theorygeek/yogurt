# typed: strict
# frozen_string_literal: true

module GraphQLClient
  class CodeGenerator
    class FieldAccessor < T::Struct
      extend T::Sig
      extend Utils
      include Utils

      # Name of the method
      const :name, Symbol

      # Sorbet signature for the value of the field
      const :signature, String

      # Expression for converting the value of the field
      const :expression, String

      # The types of all of the fragments leading to this field
      const :fragment_types, T::Array[String]

      sig {params(schema: GRAPHQL_SCHEMA).void}
      def set_possible_types!(schema)
        @possible_types = T.let(@possible_types, T.nilable(T::Set[String]))
        return @possible_types if @possible_types

        result = schema.possible_types(schema.types[fragment_types.fetch(0)]).to_set
        if fragment_types.size > 1
          T.must(fragment_types[1..-1]).each do |next_type|
            result = result.intersection(schema.possible_types(schema.types[next_type]))
          end
        end

        @possible_types = result.map(&:graphql_name).to_set.freeze
      end

      # If the runtime object is one of the `possible_types`, this field accessor
      # will return a value for the field.
      sig {returns(T::Set[String])}
      def possible_types
        @possible_types = T.let(@possible_types, T.nilable(T::Set[String]))
        if @possible_types.nil?
          raise "You must call set_possible_types! first"
        else
          @possible_types
        end
      end

      # Given the FieldAccessor's, converts them into an array of DefinedMethod's
      sig {params(schema: GRAPHQL_SCHEMA, methods: T::Hash[Symbol, T::Array[FieldAccessor]]).returns(T::Array[DefinedMethod])}
      def self.flatten(schema, methods)
        result = methods.map do |method_name, accessors|
          # We can safely eliminate the field accessors that are impossible
          accessors.each {|field_accessor| field_accessor.set_possible_types!(schema)}
          accessors = accessors.reject {|field_accessor| field_accessor.possible_types.empty?}

          # We can safely eliminate the field accessors that are subsets of other accessors
          preserve = []
          accessors.each do |field_accessor|
            supersets = preserve.select {|other| other.possible_types.superset?(field_accessor.possible_types)}
            
            if supersets.none?
              preserve << field_accessor
            else
              preserve -= supersets
              preserve << field_accessor
            end
          end

          accessors = preserve

          if accessors.none?
            # Field access is impossible. Emit a method that will always return nil.
            next DefinedMethod.new(
              name: method_name,
              signature: "NilClass",
              body: <<~STRING
                # The combination of fragments used to retrieve this field make it impossible
                # for the field to have any value other than `nil`.
                nil
              STRING
            )
          end

          # We need to mark the field nilable if the server would omit the field for some objects
          # where the fragment is spread. We can detect this by seeing if any of the accessors have a
          # set of possible types that is smaller than their root type.
          needs_nilable = accessors.any? do |field_accessor|
            root_type = schema.types[field_accessor.fragment_types[0]]
            root_possible_types = schema.possible_types(root_type).map(&:graphql_name)
            eliminated_types = (root_possible_types - field_accessor.possible_types.to_a)
            eliminated_types.any?
          end

          signatures = accessors.map do |field_accessor|
            signature = field_accessor.signature
            next signature unless signature.start_with?("T.nilable(")

            if needs_nilable
              # Since we're going to end up wrapping the composite signature in T.nilable,
              # we can strip it off of the inner signatures
              signature[10...-1]
            else
              # Preserve the original signature, even if it's nilable, because this field will
              # always be queried by the server.
              signature
            end
          end

          signatures.uniq!
          signatures.sort!

          composite_signature = if signatures.size == 1
            signatures.fetch(0)
          else
            "T.any(#{signatures.join(', ')})"
          end

          if needs_nilable
            composite_signature = "T.nilable(#{composite_signature})"
          end

          # Hash where the first value is a boolean expression (ie, "typename == 'A' || typename == 'B'")
          # and the second value is the field accessor's expression
          conditions = T.let([], T::Array[[String, String]])
          
          accessors.group_by(&:expression).each do |expression, group|
            type_names = group.map(&:possible_types).reduce(&:|).to_a.sort
            conditions << [
              type_names.map {|type| "__typename == #{type.inspect}"}.join(' || '),
              expression,
            ]
          end

          conditions.sort!
          
          if conditions.size == 1
            if needs_nilable
              composite_body = <<~STRING
                return unless #{conditions.fetch(0)[0]}
                #{conditions.fetch(0)[1]}
              STRING
            else
              composite_body = <<~STRING
                #{conditions.fetch(0)[1]}
              STRING
            end
          else
            composite_body = +<<~STRING
              if #{conditions.fetch(0)[0]}
                #{indent(conditions.fetch(0)[1], 1).strip}
            STRING

            T.must(conditions[1..-1]).each do |(condition, body)|
              composite_body << "elsif #{condition}\n"
              composite_body << "#{indent(body, 1).rstrip}\n"
            end

            if !needs_nilable
              expected_possible_types = accessors.map(&:possible_types).reduce(&:|).to_a.sort
              composite_body << "else\n"
              composite_body << "  raise GraphQLClient::UnexpectedRuntimeType.new(observed_type: __typename, expected_types: #{expected_possible_types.inspect})"
            end

            composite_body << "end"
          end

          DefinedMethod.new(
            name: method_name,
            signature: composite_signature,
            body: composite_body,
          )
        end

        result.compact!
        result
      end
    end
  end
end
