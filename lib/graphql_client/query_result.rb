# typed: strict
# frozen_string_literal: true

require 'pp'

module GraphQLClient
  module QueryResult
    extend T::Sig
    extend T::Helpers
    include Inspectable

    interface!

    class UnexpectedGraphQLTypeEncounteredError < StandardError; end

    sig {abstract.returns(OBJECT_TYPE)}
    def raw_result; end

    sig {abstract.returns(String)}
    def __typename; end
  end
end