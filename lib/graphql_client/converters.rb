# typed: strict
# frozen_string_literal: true

module GraphQLClient
  module Converters
    class Date
      extend T::Sig
      extend ScalarConverter

      sig {override.returns(T::Types::Base)}
      def self.type_alias
        T.type_alias {::Date}
      end

      sig {override.params(raw_value: SCALAR_TYPE).returns(::Date)}
      def self.deserialize(raw_value)
        if !raw_value.is_a?(String)
          raise "Unexpected value returned for Date: #{raw_value.inspect}"
        end

        ::Date.iso8601(raw_value)
      end
    end

    class Time
      extend T::Sig
      extend ScalarConverter

      sig {override.returns(T::Types::Base)}
      def self.type_alias
        T.type_alias {::Time}
      end

      sig {override.params(raw_value: SCALAR_TYPE).returns(::Time)}
      def self.deserialize(raw_value)
        if !raw_value.is_a?(String)
          raise "Unexpected value returned for Time: #{raw_value.inspect}"
        end

        ::Time.iso8601(raw_value)
      end
    end
  end
end