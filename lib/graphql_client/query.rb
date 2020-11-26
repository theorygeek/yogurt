# typed: strict
# frozen_string_literal: true

module GraphQLClient
  class Query
    extend T::Sig
    extend T::Helpers
    abstract!

    sig {params(result: OBJECT_TYPE).returns(T.any(T.attached_class, GraphQLClient::ErrorResult::OnlyErrors))}
    def self.from_result(result)
      data = result['data']
      if data
        new(data, result['errors'])
      else
        GraphQLClient::ErrorResult::OnlyErrors.new(result['errors'])
      end
    end

    sig {params(data: OBJECT_TYPE, errors: T.nilable(OBJECT_TYPE)).void}
    def initialize(data, errors); end
  end
end
