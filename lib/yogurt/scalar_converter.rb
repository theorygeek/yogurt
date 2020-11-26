# typed: strict
# frozen_string_literal: true

module Yogurt
  module ScalarConverter
    extend T::Sig
    extend T::Helpers
    interface!

    sig {abstract.returns(T::Types::Base)}
    def type_alias; end

    sig {abstract.params(value: T.untyped).returns(Yogurt::SCALAR_TYPE)}
    def serialize(value); end

    sig {abstract.params(raw_value: Yogurt::SCALAR_TYPE).returns(T.untyped)}
    def deserialize(raw_value); end
  end
end
