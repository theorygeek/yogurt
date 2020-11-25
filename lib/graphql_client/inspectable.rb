# typed: strict
# frozen_string_literal: true

require 'pp'

module GraphQLClient
  module Inspectable
    extend T::Sig
    extend T::Helpers
    include PP::ObjectMixin

    abstract!

    sig {abstract.params(p: PP::PPMethods).void}
    def pretty_print(p); end

    sig {returns(String)}
    def inspect
      pretty_print_inspect
    end
  end
end
