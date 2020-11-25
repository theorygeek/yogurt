# typed: strict
# frozen_string_literal: true

module GraphQLClient
  class CodeGenerator
    module DefinedClass
      extend T::Sig
      extend T::Helpers
      abstract!

      sig {abstract.returns(String)}
      def name; end

      sig {abstract.returns(String)}
      def to_ruby; end

      sig {abstract.returns(T::Array[String])}
      def dependencies; end
    end
  end
end
