# typed: strict
# frozen_string_literal: true

require 'pp'

module Yogurt
  module QueryResult
    extend T::Sig
    extend T::Helpers
    include Inspectable

    abstract!

    sig {abstract.returns(OBJECT_TYPE)}
    def raw_result; end

    sig {abstract.returns(String)}
    def __typename; end

    sig(:final) {params(field: Symbol, observed_type: String, expected_types: T::Array[String]).returns(T.noreturn)}
    def __unexpected_type(field:, observed_type:, expected_types:)
      Kernel.raise(UnexpectedObjectType.new(field: field, observed_type: observed_type, expected_types: expected_types))
    end
  end
end
