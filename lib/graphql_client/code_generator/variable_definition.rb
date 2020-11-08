# typed: strict
# frozen_string_literal: true

module GraphQLClient
  class CodeGenerator
    class VariableDefinition < T::Struct
      extend T::Sig
      include Comparable

      const :name, Symbol
      const :graphql_name, String
      const :signature, String
      const :serializer, String

      sig {returns(T::Boolean)}
      def optional?
        signature.start_with?("T.nilable")
      end

      sig {params(other: VariableDefinition).returns(T.nilable(Integer))}
      def <=>(other)
        if optional? && !other.optional?
          1
        elsif other.optional? && !optional?
          -1
        else
          name <=> other.name
        end
      end
    end
  end
end
