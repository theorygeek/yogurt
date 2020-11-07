# typed: ignore
# frozen_string_literal: true

class FakeExecutor
  extend T::Sig
  include GraphQLClient::QueryExecutor

  sig do
    override.params(
      query: String,
      operation_name: String,
      variables: T.nilable(T::Hash[String, T.untyped]),
      options: T.untyped
    ).returns(T::Hash[String, T.untyped])
  end
  def execute(query, operation_name:, variables: nil, options: nil)
    {}
  end

  Instance = new
end
