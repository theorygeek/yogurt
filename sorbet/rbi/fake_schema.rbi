# typed: strict

# This file has RBI definitions that are helpful for tests.
module PP::PPMethods
  def text(*); end
  def qq(*); end
  def breakable; end
  def comma_breakable; end
end

class FakeSchema < GraphQL::Schema; end
class FakeContainer
  extend GraphQLClient::QueryContainer
end
