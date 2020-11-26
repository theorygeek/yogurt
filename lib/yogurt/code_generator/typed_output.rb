# typed: strict
# frozen_string_literal: true

module Yogurt
  class CodeGenerator
    class TypedOutput < T::Struct
      # The signature to put in the sorbet type
      const :signature, String

      # Converter function to use for the return result.
      # This assumes that a local variable named `raw_value` has the
      # value to be converted.
      const :deserializer, String
    end
  end
end
