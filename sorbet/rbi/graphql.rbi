# typed: strict

class GraphQL::Schema::Member
  sig {params(new_name: T.nilable(String)).returns(String)}
  def self.graphql_name(new_name=nil); end

  sig {params(new_desc: T.nilable(String)).returns(String)}
  def self.description(new_desc=nil); end
end

class GraphQL::Schema::Scalar < GraphQL::Schema::Member; end