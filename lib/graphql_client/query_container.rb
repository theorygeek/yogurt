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
      Kernel.raise(ValidationError, "You need to `extend GraphQLClient::QueryContainer`, you cannot use `include`.")
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

    sig {params(operation_name: String).returns(QueryDeclaration)}
    def fetch_query(operation_name)
      result = declared_queries.detect {|d| d.operations.include?(operation_name)}
      T.must(result)
    end

    sig do
      params(
        query_text: String,
        schema: T.nilable(T.class_of(GraphQL::Schema))
      ).void
    end
    def declare_query(query_text, schema: nil)
      schema ||= GraphQLClient.default_schema
      if schema.nil?
        Kernel.raise(ValidationError, "You need to either provide a `schema:` to declare_query, or set GraphQLClient.default_schema")
      end

      case (container = self)
      when Module
        # noop
      else
        Kernel.raise(ValidationError, "You need to `extend GraphQLClient::QueryContainer`, you cannot use `include`.")
      end

      if container.name.nil?
        Kernel.raise(ValidationError, "Query containers must be classes or modules that are assigned to constants.")
      end

      validator = GraphQL::StaticValidation::Validator.new(schema: schema)
      query = GraphQL::Query.new(schema, query_text)
      validation_result = validator.validate(query)
      validation_result[:errors].each do |error|
        Kernel.raise(ValidationError, error.message)
      end

      if query.operations.key?(nil)
        Kernel.raise(ValidationError, "You must provide a name for each of the operations in your GraphQL query.")
      elsif query.operations.none?
        Kernel.raise(ValidationError, "Your query did not define any operations.")
      end

      declared_queries << QueryDeclaration.new(
        container: container,
        operations: query.operations.keys.freeze,
        query_text: query_text,
        schema: schema,
      )
    end
  end
end