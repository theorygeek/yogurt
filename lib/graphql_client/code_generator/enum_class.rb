# typed: strict
# frozen_string_literal: true

module GraphQLClient
  class CodeGenerator
    # For GraphQL enum classes
    class EnumClass < T::Struct
      extend T::Sig
      include Utils
      include DefinedClass

      const :name, String
      const :serialized_values, T::Array[String]
      
      sig {override.returns(T::Array[String])}
      def dependencies
        []
      end

      sig {override.returns(String)}
      def to_ruby
        existing_constants = []

        definitions = serialized_values.sort.map do |name|
          const_name = safe_constant_name(name, existing_constants)
          existing_constants << const_name
          "#{const_name} = new(#{name.inspect})"
        end

        <<~STRING
          class #{name} < T::Enum
            enums do
              #{indent(definitions.join("\n"), 2).strip}
            end
          end
        STRING
      end

      # Returns a valid Ruby constant name that doesn't conflict with the
      # existing constants.
      sig {params(desired_name: String, existing_constants: T::Array[String]).returns(String)}
      private def safe_constant_name(desired_name, existing_constants)
        desired_name = underscore(desired_name).upcase
        base_desired_name = desired_name
        escaping_level = 1

        while existing_constants.include?(desired_name)
          escaping_level += 1
          desired_name = "#{base_desired_name}#{escaping_level}"
        end

        desired_name
      end
    end
  end
end