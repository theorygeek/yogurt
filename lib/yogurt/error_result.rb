# typed: strict
# frozen_string_literal: true

module Yogurt
  module ErrorResult
    include Kernel
    extend T::Sig
    extend T::Helpers

    interface!

    sig {abstract.returns(T.nilable(T::Array[OBJECT_TYPE]))}
    def errors; end

    class OnlyErrors
      extend T::Sig
      include ErrorResult

      sig {params(errors: T::Array[OBJECT_TYPE]).void}
      def initialize(errors)
        @errors = T.let(errors, T::Array[OBJECT_TYPE])
      end

      sig {override.returns(T.nilable(T::Array[OBJECT_TYPE]))}
      def errors
        @errors
      end
    end
  end
end
