# typed: strict
# frozen_string_literal: true

module GraphQLClient
  class CodeGenerator
    class OperationDeclaration < T::Struct
      const :declaration, QueryDeclaration
      const :operation_name, String
      const :variables, T::Array[GraphQL::Language::Nodes::VariableDefinition]
    end
  end
end