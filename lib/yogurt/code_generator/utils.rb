# typed: strict
# frozen_string_literal: true

module Yogurt
  class CodeGenerator
    module Utils
      extend T::Sig
      extend self

      sig {params(schema: GRAPHQL_SCHEMA, graphql_type: T.untyped).returns(String)}
      def typename_method(schema, graphql_type)
        possible_types = schema.possible_types(graphql_type)

        if possible_types.size == 1
          <<~STRING
            sig {override.returns(String)}
            def __typename
              #{possible_types.fetch(0).graphql_name.inspect}
            end
          STRING
        else
          <<~STRING
            sig {override.returns(String)}
            def __typename
              raw_result["__typename"]
            end
          STRING
        end
      end

      sig {params(schema: GRAPHQL_SCHEMA, graphql_type: T.untyped).returns(String)}
      def possible_types_constant(schema, graphql_type)
        possible_types = schema
          .possible_types(graphql_type)
          .map(&:graphql_name)
          .sort
          .map(&:inspect)

        single_line = possible_types.join(', ')
        if single_line.size <= 80
          <<~STRING.strip
            POSSIBLE_TYPES = T.let(
              [#{single_line}],
              T::Array[String]
            )
          STRING
        else
          multi_line = possible_types.join(",\n")
          <<~STRING.strip
            POSSIBLE_TYPES = T.let(
              [
                #{indent(multi_line, 2).strip}
              ].freeze,
              T::Array[String]
            )
          STRING
        end
      end

      sig {params(camel_cased_word: String).returns(String)}
      def underscore(camel_cased_word)
        return camel_cased_word unless /[A-Z-]|::/.match?(camel_cased_word)

        word = camel_cased_word.to_s.gsub("::", "/")
        word.gsub!(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2')
        word.gsub!(/([a-z\d])([A-Z])/, '\1_\2')
        word.tr!("-", "_")
        word.downcase!
        word
      end

      sig {params(term: String).returns(String)}
      def camelize(term)
        string = term.to_s
        string = string.sub(/^[a-z\d]*/, &:capitalize)
        string.gsub!(%r{(?:_|(/))([a-z\d]*)}i) {"#{Regexp.last_match(1)}#{T.must(Regexp.last_match(2)).capitalize}"}
        string.gsub!("/", "::")
        string
      end

      sig {params(string: String, amount: Integer).returns(String)}
      def indent(string, amount)
        return string if amount.zero?

        padding = '  ' * amount

        buffer = T.unsafe(String).new("", capacity: string.size)
        string.each_line do |line|
          buffer << padding if line.size > 1 || line != "\n"
          buffer << line
        end

        buffer
      end

      sig {params(desired_name: String).returns(Symbol)}
      def generate_method_name(desired_name)
        base_desired_name = desired_name
        escaping_level = 0

        while PROTECTED_NAMES.include?(desired_name)
          escaping_level += 1
          desired_name = "#{base_desired_name}#{'_' * escaping_level}"
        end

        desired_name.to_sym
      end

      sig {params(methods: T::Array[DefinedMethod]).returns(String)}
      def generate_pretty_print(methods)
        inspect_lines = methods.map do |dm|
          <<~STRING
            p.comma_breakable
            p.text(#{dm.name.to_s.inspect})
            p.text(': ')
            p.pp(#{dm.name})
          STRING
        end

        object_group = <<~STRING.strip
          p.breakable
          p.text('__typename')
          p.text(': ')
          p.pp(__typename)

          #{inspect_lines.join("\n\n")}
        STRING

        <<~STRING
          sig {override.params(p: T.untyped).void}
          def pretty_print(p)
            p.object_group(self) do
              #{indent(object_group, 2).strip}
            end
          end
        STRING
      end
    end
  end
end
