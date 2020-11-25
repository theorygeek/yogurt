# typed: strict
# frozen_string_literal: true

module GraphQLClient
  class UnexpectedObjectType < StandardError
    extend T::Sig

    sig {returns(Symbol)}
    attr_reader :field

    sig {returns(String)}
    attr_reader :observed_type

    sig {returns(T::Array[String])}
    attr_reader :expected_types

    sig {params(field: Symbol, observed_type: String, expected_types: T::Array[String]).void}
    def initialize(field:, observed_type:, expected_types:)
      @field = T.let(field, Symbol)
      @observed_type = T.let(observed_type, String)
      @expected_types = T.let(expected_types, T::Array[String])

      super <<~STRING
        Unexpected type returned in GraphQL response for #{field}. 
        Received: #{observed_type}
        Expected: #{expected_types.join(', ')}
      STRING
    end
  end
end
