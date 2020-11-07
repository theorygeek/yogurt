# typed: strict
# frozen_string_literal: true

module GraphQLClient
  class CodeGenerator
    class TypedExpression < T::Struct
      # The signature to put in the sorbet type
      const :signature, String

      # Converter function to use for the return result.
      # This assumes that a local variable named `raw_value` has the
      # value to be converted.
      const :converter, String
    end
  end
end