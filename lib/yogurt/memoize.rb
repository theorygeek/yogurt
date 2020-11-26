# typed: strict
# frozen_string_literal: true

module Yogurt
  module Memoize
    extend T::Sig

    sig do
      type_parameters(:ReturnType)
        .params(
          name: Symbol,
          block: T.proc.returns(T.type_parameter(:ReturnType)),
        )
        .returns(T.type_parameter(:ReturnType))
    end
    def memoize_as(name, &block)
      memoized_values = @memoized_values
      memoized_values = @memoized_values = {} if memoized_values.nil?

      return memoized_values[name] if memoized_values.key?(name)

      memoized_values[name] = yield
    end

    sig {returns(T.self_type)}
    def freeze
      @memoized_values = T.let(@memoized_values, T.nilable(T::Hash[Symbol, T.untyped]))
      @memoized_values&.freeze
      super
      self
    end
  end
end
