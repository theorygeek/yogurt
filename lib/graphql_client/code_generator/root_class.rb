# typed: strict
# frozen_string_literal: true

module GraphQLClient
  class CodeGenerator
    # Root classes are generated for the root of a GraphQL query.
    class RootClass < T::Struct
      include DefinedClass
      extend T::Sig
      include Utils

      const :name, String
      const :schema, GRAPHQL_SCHEMA
      const :operation_name, String
      const :graphql_type, T.untyped
      const :query_container, QueryContainer::CONTAINER
      const :defined_methods, T::Array[DefinedMethod]
      const :variables, T::Array[VariableDefinition]
      const :dependencies, T::Array[String]

      sig {override.returns(String)}
      def to_ruby
        pretty_print = generate_pretty_print(defined_methods)
        declaration = query_container.fetch_query(operation_name)
        original_query = declaration.query_text
        parsed_query = GraphQL.parse(original_query)
        reprinted_query = GraphQL::Language::Printer.new.print(parsed_query)

        dynamic_methods = <<~STRING.strip
          #{defined_methods.map(&:to_ruby).join("\n")}
          #{pretty_print}
        STRING

        <<~STRING
          class #{name} < GraphQLClient::Query
            extend T::Sig
            include GraphQLClient::QueryResult
            include GraphQLClient::ErrorResult

            SCHEMA = T.let(#{schema.name}, GraphQLClient::GRAPHQL_SCHEMA)
            OPERATION_NAME = T.let(#{operation_name.inspect}, String)
            QUERY_TEXT = T.let(<<~'GRAPHQL', String)
              #{indent(reprinted_query, 2).strip}
            GRAPHQL
            #{indent(possible_types_constant(schema, graphql_type), 1).strip}

            #{indent(execute_method, 1).strip}

            sig {params(data: GraphQLClient::OBJECT_TYPE, errors: T.nilable(T::Array[GraphQLClient::OBJECT_TYPE])).void}
            def initialize(data, errors)
              @result = T.let(data, GraphQLClient::OBJECT_TYPE)
              @errors = T.let(errors, T.nilable(T::Array[GraphQLClient::OBJECT_TYPE]))
            end

            sig {override.returns(GraphQLClient::OBJECT_TYPE)}
            def raw_result
              @result
            end

            #{indent(typename_method(schema, graphql_type), 1).strip}

            sig {override.returns(T.nilable(T::Array[GraphQLClient::OBJECT_TYPE]))}
            def errors
              @errors
            end

            #{indent(dynamic_methods, 1).strip}
          end
        STRING
      end

      sig {returns(String)}
      def execute_method
        executor = GraphQLClient.registered_schemas.fetch(schema)
        options_type = executor.options_type_alias.name
        signature_params = ["options: #{options_type}"]
        
        params = if options_type.start_with?("T.nilable")
          ["options=nil"]
        else
          ["options"]
        end

        variable_extraction = if variables.any?
          serializers = []
        
          variables.sort.each do |variable|
            if variable.signature.start_with?("T.nilable")
              params.push("#{variable.name}: nil")
            else
              params.push("#{variable.name}:")
            end

            signature_params.push("#{variable.name}: #{variable.signature}")
            serializers.push(<<~STRING.strip)
              #{variable.graphql_name.inspect} => #{variable.serializer.strip},
            STRING
          end

          <<~STRING
            {
              #{indent(serializers.join("\n"), 1).strip}
            }
          STRING
        else
          "nil"
        end

        <<~STRING
          sig do
            params(
              #{indent(signature_params.join(",\n"), 2).strip}
            ).returns(T.any(T.attached_class, GraphQLClient::ErrorResult))
          end
          def self.execute(#{params.join(", ")})
            raw_result = GraphQLClient.execute(
              query: QUERY_TEXT,
              schema: SCHEMA,
              operation_name: OPERATION_NAME,
              options: options,
              variables: #{indent(variable_extraction, 2).strip}
            )

            from_result(raw_result)
          end
        STRING
      end
    end
  end
end
