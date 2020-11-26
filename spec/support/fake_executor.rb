# typed: ignore
# frozen_string_literal: true

class FakeExecutor
  extend T::Sig
  include Yogurt::QueryExecutor

  OPTIONS_TYPE = T.type_alias {T.nilable(T::Hash[String, String])}

  sig {override.returns(T::Types::Base)}
  def options_type_alias
    OPTIONS_TYPE
  end

  sig do
    override.params(
      query: String,
      operation_name: String,
      variables: T.nilable(T::Hash[String, T.untyped]),
      options: OPTIONS_TYPE,
    ).returns(T::Hash[String, T.untyped])
  end
  def execute(query, operation_name:, variables: nil, options: nil)
    {}
  end

  Instance = new
end
