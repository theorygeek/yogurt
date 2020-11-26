# typed: strict
# frozen_string_literal: true

module Yogurt
  class CodeGenerator
    class TypeWrapper < T::Enum
      enums do
        NILABLE = new
        ARRAY = new
      end
    end
  end
end
