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

    sig {params(constant_name: Symbol, query_text: String).void}
    def declare_query(constant_name, query_text)
      case (container = self)
      when Module
        # noop
      else
        Kernel.raise("You need to `extend GraphQLClient::QueryContainer`, you cannot use `include`.")
      end

      declared_queries << QueryDeclaration.new(
        container: container,
        constant_name: constant_name,
        query_text: query_text
      )
    end
  end
end