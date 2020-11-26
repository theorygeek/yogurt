# typed: strict
# frozen_string_literal: true

module Yogurt
  class CodeGenerator
    # Leaf classes are generated for the inner types of query results.
    class LeafClass < T::Struct
      include DefinedClass
      extend T::Sig
      include Utils

      const :name, String
      const :schema, GRAPHQL_SCHEMA
      const :graphql_type, T.untyped # rubocop:disable Sorbet/ForbidUntypedStructProps
      prop :defined_methods, T::Array[DefinedMethod]
      prop :dependencies, T::Array[String]

      # Adds the defined methods to the ones that are already defined in the class
      sig {params(extra_methods: T::Array[DefinedMethod]).void}
      def merge_defined_methods(extra_methods)
        own_methods = defined_methods.map {|dm| [dm.name, dm]}.to_h
        extra_methods.each do |extra|
          own = own_methods[extra.name]
          if own.nil?
            own_methods[extra.name] = extra
          elsif !own.merge?(extra)
            raise "Cannot merge method #{extra.inspect} into #{own.inspect}"
          end
        end

        self.defined_methods = own_methods.values
      end

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
            include Yogurt::QueryResult

            #{indent(possible_types_constant(schema, graphql_type), 1).strip}

            sig {params(result: Yogurt::OBJECT_TYPE).void}
            def initialize(result)
              @result = T.let(result, Yogurt::OBJECT_TYPE)
            end

            sig {override.returns(Yogurt::OBJECT_TYPE)}
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
