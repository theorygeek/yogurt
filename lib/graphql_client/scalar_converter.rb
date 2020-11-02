# typed: strict
# frozen_string_literal: true

module GraphQLClient
  class ScalarConverter < T::Struct
    const :schema, GRAPHQL_SCHEMA
    const :graphql_type, String
    const :sorbet_type, String
    const :converter, Proc
  end
end