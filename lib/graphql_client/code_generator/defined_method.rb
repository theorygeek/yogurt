# typed: strict
# frozen_string_literal: true

module GraphQLClient
  class CodeGenerator
    module DefinedMethod
      extend T::Sig
      extend T::Helpers
      abstract!

      sig {abstract.returns(Symbol)}
      def name; end

      sig {abstract.returns(String)}
      def to_ruby; end
    end
  end
end