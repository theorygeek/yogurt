# typed: strict
# frozen_string_literal: true

module GraphQLClient
  module QueryContainer
    extend T::Sig

    CONTAINER = T.type_alias do
      T.all(Module, QueryContainer)
    end

    sig {params(other: Module).void}
    def self.included(other)
      Kernel.raise("You need to `extend GraphQLClient::QueryContainer`, you cannot use `include`.")
    end

    sig {params(other: Module).void}
    def self.extended(other)
      super
      QueryContainer.containers << T.cast(other, CONTAINER)
    end

    sig {returns(T::Array[CONTAINER])}
    def self.containers
      @containers = T.let(@containers, T.nilable(T::Array[CONTAINER]))
      @containers ||= []
    end

    sig {returns(T::Array[QueryDeclaration])}
    def declared_queries
      @declared_queries = T.let(@declared_queries, T.nilable(T::Array[QueryDeclaration]))
      @declared_queries ||= []
    end

    sig do
      params(
        constant_name: Symbol,
        query_text: String,
        schema: T.nilable(T.class_of(GraphQL::Schema))
      ).void
    end
    def declare_query(constant_name, query_text, schema: nil)
      schema ||= GraphQLClient.default_schema
      if schema.nil?
        Kernel.raise("You need to either provide a `schema:` to declare_query, or set GraphQLClient.default_schema")
      end

      case (container = self)
      when Module
        # noop
      else
        Kernel.raise("You need to `extend GraphQLClient::QueryContainer`, you cannot use `include`.")
      end

      validator = GraphQL::StaticValidation::Validator.new(schema: schema)
      query = GraphQL::Query.new(schema, query_text)
      validation_result = validator.validate(query)
      validation_result[:errors].each do |error|
        Kernel.raise ValidationError, error.message
      end

      if query.operations.key?(nil)
        Kernel.raise("You must provide a name for each of the operations in your GraphQL query.")
      elsif query.operations.none?
        Kernel.raise("Your query did not define any operations.")
      end

      declared_queries << QueryDeclaration.new(
        container: container,
        constant_name: constant_name,
        query_text: query_text,
        schema: schema,
      )
    end
  end
end