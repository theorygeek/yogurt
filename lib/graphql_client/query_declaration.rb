# typed: strict
# frozen_string_literal: true

module GraphQLClient
  class QueryDeclaration < T::Struct
    const :container, T.all(Module, QueryContainer)
    const :constant_name, Symbol
    const :query_text, String
  end
end
