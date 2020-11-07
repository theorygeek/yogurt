# typed: strict
# frozen_string_literal: true

module GraphQLClient
  class CodeGenerator
    class TypeWrapper < T::Enum
      enums do
        NILABLE = new
        ARRAY = new
      end
    end
  end
end
