# typed: strict
# frozen_string_literal: true

module Yogurt
  class CodeGenerator
    class TypedInput < T::Struct
      const :signature, String
      const :serializer, String
      const :dependency, T.nilable(String)
    end
  end
end
