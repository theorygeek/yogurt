# typed: strict
# frozen_string_literal: true

module GraphQLClient
  class Query
    extend T::Sig
    extend T::Helpers
    abstract!

    sig {params(result: T::Hash[String, T.untyped]).returns(T.any(T.attached_class, GraphQLClient::ErrorResult))}
    def self.from_result(result)
      data = result['data']
      if data
        new(data, result['errors'])
      else
        GraphQLClient::ErrorResult::OnlyErrors.new(result['errors'])
      end
    end

    sig {params(data: T::Hash[String, T.untyped], errors: T.nilable(T::Hash[String, T.untyped])).void}
    def initialize(data, errors); end
  end
end