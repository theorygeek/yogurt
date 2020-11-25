# typed: strict
# frozen_string_literal: true

module GraphQLClient
  class CodeGenerator
    module DefinedMethod
      extend T::Sig
      extend T::Helpers
      include Kernel
      abstract!

      sig {abstract.returns(Symbol)}
      def name; end

      # Attempts to merge this method with the other defined method. Returns true if
      # successful, false if they are incompatible.
      sig {abstract.params(other: DefinedMethod).returns(T::Boolean)}
      def merge?(other); end

      sig {abstract.returns(String)}
      def to_ruby; end
    end
  end
end
