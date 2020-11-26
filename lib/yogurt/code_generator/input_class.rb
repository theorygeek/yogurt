# typed: strict
# frozen_string_literal: true

module Yogurt
  class CodeGenerator
    # Input classes are used for input objects
    class InputClass < T::Struct
      extend T::Sig
      include Utils
      include DefinedClass

      const :name, String
      const :arguments, T::Array[VariableDefinition]

      sig {override.returns(T::Array[String])}
      def dependencies
        arguments.map(&:dependency).compact
      end

      sig {override.returns(String)}
      def to_ruby
        extract = []
        props = []
        serializers = []
        arguments.sort.each do |definition|
          props << "prop #{definition.name.inspect}, #{definition.signature}"
          extract << "#{definition.name} = self.#{definition.name}"
          serializers.push(<<~STRING.strip)
            #{definition.graphql_name.inspect} => #{definition.serializer.strip},
          STRING
        end

        <<~STRING
          class #{name} < T::Struct
            extend T::Sig

            #{indent(props.join("\n"), 1).strip}

            sig {returns(T::Hash[String, T.untyped])}
            def serialize
              #{indent(extract.join("\n"), 2).strip}

              {
                #{indent(serializers.join("\n"), 3).strip}
              }
            end
          end
        STRING
      end
    end
  end
end
