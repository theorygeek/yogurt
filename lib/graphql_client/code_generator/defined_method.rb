# typed: strict
# frozen_string_literal: true

module GraphQLClient
  class CodeGenerator
    class DefinedMethod < T::Struct
      extend T::Sig
      include Utils

      # Name of the method
      const :name, Symbol

      # Sorbet signature for the method
      const :signature, String

      # Body of the method
      const :body, String

      sig {returns(String)}
      def to_ruby
        <<~STRING
          sig {returns(#{signature})}
          def #{name}
            #{indent(body, 1).strip}
          end
        STRING
      end
    end
  end
end