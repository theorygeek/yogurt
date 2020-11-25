# typed: strict
# frozen_string_literal: true

module GraphQLClient
  class UnexpectedRuntimeType < StandardError
    extend T::Sig

    sig {params(observed_type: String, expected_types: T::Array[String]).void}
    def initialize(observed_type:, expected_types:)
      message = "Unexpected type returned in GraphQL response. Received #{observed_type}, expected one of: #{expected_types.join(', ')}"
      super(message)
    end
  end
end
