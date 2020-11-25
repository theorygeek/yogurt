# typed: strict
# frozen_string_literal: true

module GraphQLClient
  module QueryExecutor
    extend T::Sig
    extend T::Helpers
    interface!

    sig {abstract.returns(T::Types::Base)}
    def options_type_alias; end

    sig do
      abstract.params(
        query: String,
        operation_name: String,
        variables: T.nilable(T::Hash[String, T.untyped]),
        options: T.untyped,
      ).returns(T::Hash[String, T.untyped])
    end
    def execute(query, operation_name:, variables: nil, options: nil); end
  end
end
