# typed: strict
# frozen_string_literal: true

require 'pp'

module GraphQLClient
  module QueryResult
    extend T::Sig
    extend T::Helpers
    include Inspectable

    interface!

    sig {abstract.returns(T::Hash[String, T.untyped])}
    def raw_result; end
  end
end