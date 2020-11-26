# typed: strict
# frozen_string_literal: true

module Yogurt
  class CodeGenerator
    # Method that is used to access a field on an object
    class FieldAccessMethod < T::Struct
      extend T::Sig
      include Memoize
      include DefinedMethod
      include Utils

      # Indicates the possible object types that could occur at runtime, and which expressions
      # should be used if that object type appears.
      class FragmentBranch < T::Struct
        extend T::Sig
        include Comparable
        include Memoize
        include Utils

        const :typenames, T::Set[String]
        const :expression, String

        sig {returns(T::Array[String])}
        def sorted_typenames
          memoize_as(:sorted_typenames) {typenames.to_a.sort}
        end

        sig {returns(String)}
        def to_ruby
          <<~STRING.strip
            when #{sorted_typenames.map(&:inspect).join(', ')}
            #{indent(expression, 1)}
          STRING
        end

        sig {override.params(other: T.untyped).returns(T.nilable(Integer))}
        def <=>(other)
          return unless other.is_a?(FragmentBranch)

          comparison = sorted_typenames <=> other.sorted_typenames
          return comparison if comparison != 0

          expression <=> other.expression
        end
      end

      IMPOSSIBLE_FIELD_SIGNATURE = T.let("NilClass", String)
      IMPOSSIBLE_FIELD_BODY = T.let(<<~STRING, String)
        # The combination of fragments used to retrieve this field make it impossible
        # for the field to have any value other than `nil`.
        nil
      STRING

      # Name of the method
      const :name, Symbol

      # Paths with the fragments that indicate how this method is accessed
      const :field_access_paths, T::Array[FieldAccessPath]

      # GraphQL schema for the query that is executing
      const :schema, GRAPHQL_SCHEMA

      # Attempts to merge this method with the other defined method. Returns true if
      # successful, false if they are incompatible.
      sig {override.params(other: DefinedMethod).returns(T::Boolean)}
      def merge?(other)
        return false unless other.is_a?(FieldAccessMethod)

        field_access_paths.concat(other.field_access_paths)
        true
      end

      sig {override.returns(String)}
      def to_ruby
        <<~STRING
          sig {returns(#{signature})}
          def #{name}
            #{indent(body, 1).strip}
          end
        STRING
      end

      # Returns the different branches of execution that could happen based on the actual
      # object type that is returned by the GraphQL query.
      sig {returns(T::Array[FragmentBranch])}
      def branches
        reduce!
        memoize_as(:branches) do
          # Construct the branches for each of the possible fragments. When grouped by
          # expression, the typenames possible for each branch should be disjoint. If they're
          # not, the query would have been rejected as invalid by the `FieldsWillMerge`
          # static validation rule.
          result = field_access_paths.group_by(&:expression).map do |expression, group|
            typenames = T.let(Set.new, T::Set[String])
            group.each do |path|
              typenames.merge(path.compatible_object_types)
            end

            FragmentBranch.new(expression: expression, typenames: typenames)
          end

          # Invariant: Make sure that the behavior of the world matches our expectations.
          invalid_branches = result.combination(2).select do |b1, b2|
            next if b1.nil?
            next if b2.nil?

            b1.typenames.intersect?(b2.typenames)
          end

          if invalid_branches.any?
            raise <<~STRING
              Some field access branches have overlapping types, but different field resolution expressions.
              #{invalid_branches.map {|b1, b2| { branch1: T.must(b1).serialize, branch2: T.must(b2).serialize }}.inspect}
            STRING
          end

          result.sort!
          result.freeze
        end
      end

      sig {returns(String)}
      def body
        reduce!
        memoize_as(:body) do
          break IMPOSSIBLE_FIELD_BODY if field_access_is_impossible?

          if field_access_is_guaranteed? && branches.size == 1
            branches.fetch(0).expression
          elsif field_access_is_guaranteed?
            <<~STRING
              case (type = __typename)
              #{branches.map(&:to_ruby).join("\n")}
              else
                __unexpected_type(field: #{name.inspect}, observed_type: type, expected_types: POSSIBLE_TYPES)
              end
            STRING
          elsif branches.size == 1
            branch = branches.fetch(0)
            condition = branch.sorted_typenames.map {|type| "type == #{type.inspect}"}.join(' || ')
            <<~STRING
              type = __typename
              return unless #{condition}
              #{branch.expression}
            STRING
          else
            <<~STRING
              case (type = __typename)
              #{branches.map(&:to_ruby).join("\n")}
              end
            STRING
          end
        end
      end

      sig {returns(String)}
      def signature
        reduce!
        memoize_as(:signature) do
          break IMPOSSIBLE_FIELD_SIGNATURE if field_access_is_impossible?

          signatures = field_access_paths.map do |path|
            signature = path.signature
            next signature if !signature.start_with?("T.nilable")

            # Preserve the original signature if we're guaranteed to always return this field
            next signature if field_access_is_guaranteed?

            # If fragments might cause the field to be omitted, strip off the nilability
            # because we'll wrap the composite signature in a `T.nilable`
            signature.delete_prefix("T.nilable(").delete_suffix(")")
          end

          signatures.uniq!
          signatures.sort!

          composite_signature = if signatures.size == 1
            signatures.fetch(0)
          else
            "T.any(#{signatures.join(', ')})"
          end

          if field_access_is_guaranteed?
            composite_signature
          else
            "T.nilable(#{composite_signature})"
          end
        end
      end

      sig {returns(T::Boolean)}
      def field_access_is_impossible?
        reduce!
        field_access_paths.none?
      end

      # Returns true if this field will always be evaluated when the query is run.
      # Returns false if it's possible for the field to be excluded from the query because
      # the types of the fragments might not match the type of the object.
      sig {returns(T::Boolean)}
      def field_access_is_guaranteed?
        reduce!
        memoize_as(:field_access_is_guaranteed?) do
          # Field access is not guaranteed if, after eliminating all of the unnecessary field
          # access paths, there are any that only return a value for a subset of the possible
          # field types at the root of the fragment.
          field_access_paths.all? do |path|
            root_possible_types.subset?(path.compatible_object_types)
          end
        end
      end

      # Returns the types of objects that are possible at the root of all of the
      # field access paths. This will be the same for all of the field access paths,
      # since they should all be starting from the same place.
      sig {returns(T::Set[String])}
      private def root_possible_types
        reduce!
        memoize_as(:root_possible_types) do
          root_type = field_access_paths[0]&.fragment_types&.fetch(0)
          break Set.new if root_type.nil?

          raise "Invariant violated: Expected all FieldAccessPath's to have the same root fragment type." if !field_access_paths.all? {|path| path.fragment_types.fetch(0) == root_type}

          schema.possible_types(schema.types[root_type]).map(&:graphql_name).to_set
        end
      end

      # Eliminates field access paths that are impossible or reduntant
      sig {void}
      private def reduce!
        memoize_as(:reduce!) do
          # Eliminate paths where there are no objects that could possibly satisfy the fragment conditions
          #
          # For example:
          #
          # query {
          #   node(id: "foobar") {
          #     ... on Commit {
          #       ... on Node {
          #         ... on User {
          #           # This field can never be accessed, because User's will never be Commit's
          #           id
          #         }
          #       }
          #     }
          #   }
          # }

          field_access_paths.reject! {|path| path.compatible_object_types.empty?}

          # Eliminate paths where the compatible object types are a subset of some other path's
          # compatible object types. (These are redundant.)
          supersets = T.let([], T::Array[FieldAccessPath])

          # Put all of the supersets at the beginning of the array
          field_access_paths.sort_by! {|path| -path.compatible_object_types.size}
          field_access_paths.each do |path|
            next if supersets.any? {|super_path| super_path.compatible_object_types.superset?(path.compatible_object_types)}

            supersets.push(path)
          end

          field_access_paths.select! {|path| supersets.include?(path)}
          field_access_paths.each(&:freeze)
          field_access_paths.freeze
          true
        end
      end
    end
  end
end
