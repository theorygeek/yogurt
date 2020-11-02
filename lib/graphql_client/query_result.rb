# typed: strict
# frozen_string_literal: true

module GraphQLClient
  module QueryResult
    extend T::Sig
    extend T::Helpers

    interface!

    sig {abstract.returns(T.nilable(T::Hash[String, T.untyped]))}
    def __raw_result; end
  end
end