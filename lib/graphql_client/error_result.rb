# typed: strict
# frozen_string_literal: true

module GraphQLClient
  module ErrorResult
    extend T::Sig
    extend T::Helpers

    interface!

    sig {abstract.returns(T.nilable(T::Array[T::Hash[String, T.untyped]]))}
    def errors; end

    class OnlyErrors
      extend T::Sig
      include ErrorResult

      sig {params(errors: T::Array[T::Hash[String, T.untyped]]).void}
      def initialize(errors)
        @errors = T.let(errors, T::Array[T::Hash[String, T.untyped]])
      end

      sig {override.returns(T.nilable(T::Array[T::Hash[String, T.untyped]]))}
      def errors
        @errors
      end
    end
  end
end