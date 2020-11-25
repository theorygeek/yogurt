# typed: strict
# frozen_string_literal: true

module GraphQLClient
  module QueryContainer
    module InterfacesAndUnionsHaveTypename
      include Kernel
      extend T::Sig

      class Error < GraphQL::StaticValidation::Error
        extend T::Sig

        sig {returns(T.nilable(String))}
        attr_reader :type_name

        sig {returns(String)}
        attr_reader :node_name

        sig do
          params(
            message: String,
            node_name: String,
            path: T.nilable(String),
            nodes: T.untyped,
            type: T.nilable(String),
          ).void
        end
        def initialize(message, node_name:, path: nil, nodes: [], type: nil)
          super(message, path: path, nodes: nodes)
          @node_name = T.let(node_name, String)
          @type_name = T.let(type, T.nilable(String))
        end

        # A hash representation of this Message
        sig {returns(T::Hash[String, T.untyped])}
        def to_h
          extensions = {
            "code" => code,
            "nodeName" => @node_name
          }

          extensions['typeName'] = @type_name if @type_name
          super.merge({ "extensions" => extensions })
        end

        sig {returns(String)}
        def code
          "interfaceOrUnionMissingTypename"
        end
      end

      sig {params(node: GraphQL::Language::Nodes::Field, parent: T.untyped).void}
      def on_field(node, parent)
        super if validate_interface_union_includes_typename(node, T.unsafe(self).field_definition.type.unwrap)
      end

      sig {params(node: GraphQL::Language::Nodes::OperationDefinition, parent: T.untyped).void}
      def on_operation_definition(node, parent)
        super if validate_interface_union_includes_typename(node, T.unsafe(self).type_definition)
      end

      sig do
        params(
          node: T.any(GraphQL::Language::Nodes::Field, GraphQL::Language::Nodes::OperationDefinition),
          type_definition: T.untyped,
        ).returns(T::Boolean)
      end
      private def validate_interface_union_includes_typename(node, type_definition)
        return true if node.selections.nil?
        return true if node.selections.empty?

        type_kind = type_definition.kind
        return true unless type_kind.interface? || type_kind.union?
        return true if node.selections.any? do |selection|
          next false unless selection.is_a?(GraphQL::Language::Nodes::Field)
          next false unless selection.name == '__typename'

          selection.alias.nil?
        end

        msg = "Interfaces and unions must include the __typename field (%{node_name} returns #{type_definition.graphql_name} but doesn't select __typename)"
        node_name = case node
        when GraphQL::Language::Nodes::Field
          "field '#{node.name}'"
        when GraphQL::Language::Nodes::OperationDefinition
          if node.name.nil?
            "anonymous query"
          else
            "#{node.operation_type} '#{node.name}'"
          end
        else
          T.absurd(node)
        end

        send(:add_error, Error.new(
          format(msg, node_name: node_name),
          nodes: node,
          node_name: node_name,
          type: type_definition.graphql_name,
                         ))

        false
      end
    end
  end
end
