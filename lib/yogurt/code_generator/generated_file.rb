# typed: strict
# frozen_string_literal: true

module Yogurt
  class CodeGenerator
    class GeneratedFile < T::Struct
      extend T::Sig

      class FileType < T::Enum
        enums do
          # File contains the definition of a GraphQL Enum
          ENUM = new('enum')

          # File contains the definition of a GraphQL operation (ie, a root query result)
          OPERATION = new('operation')

          # File contains the definition of a GraphQL object result (ie, a non-root query result)
          OBJECT_RESULT = new('object_result')

          # File contains the definition of a GraphQL input object
          INPUT_OBJECT = new('input_object')
        end
      end

      # The name of the constant that is stored in this file
      const :constant_name, String

      # Type of constant that is stored in this file
      const :type, FileType

      # Names of the constants that this file references. If you are not using an
      # autoloading tool, the files containing these constants need to be `require`'d
      # at the start of the file.
      const :dependencies, T::Array[String]

      # The code that defines the constant that is stored in this file
      const :code, String

      # Full contents of the file
      sig {returns(String)}
      def contents
        <<~STRING
          # typed: strict
          # frozen_string_literal: true

          #{code}
        STRING
      end
    end
  end
end
