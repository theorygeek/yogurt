# typed: strict
# frozen_string_literal: true

module Yogurt
  class Query
    extend T::Sig
    extend T::Helpers
    abstract!

    sig {params(result: OBJECT_TYPE).returns(T.any(T.attached_class, Yogurt::ErrorResult::OnlyErrors))}
    def self.from_result(result)
      data = result['data']
      if data
        new(data, result['errors'])
      else
        Yogurt::ErrorResult::OnlyErrors.new(result['errors'])
      end
    end

    sig {params(data: OBJECT_TYPE, errors: T.nilable(OBJECT_TYPE)).void}
    def initialize(data, errors); end
  end
end
