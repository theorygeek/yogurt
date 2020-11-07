# typed: strict
# frozen_string_literal: true

module GraphQLClient
  class CodeGenerator
    extend T::Sig
    include Utils

    PROTECTED_NAMES = T.let([
      *Object.instance_methods,
      *GraphQLClient::QueryResult.instance_methods,
      *GraphQLClient::ErrorResult.instance_methods,
    ].map(&:to_s).sort.uniq.freeze, T::Array[String])

    sig {returns(T::Hash[String, DefinedClass])}
    attr_reader :classes

    sig {params(schema: GRAPHQL_SCHEMA).void}
    def initialize(schema)
      @schema = T.let(schema, GRAPHQL_SCHEMA)
      @enums = T.let({}, T::Hash[String, String])
      @scalars = T.let(GraphQLClient.scalar_converters(schema), T::Hash[String, ScalarConverter])
      @classes = T.let({}, T::Hash[String, DefinedClass])
    end

    sig {returns(String)}
    def contents
      definitions = classes
        .sort_by {|name, definition| name}
        .map {|(name, definition)| definition.to_ruby}
        .join("\n\n")

      <<~STRING
      # typed: strict
      # frozen_string_literal: true

      require 'pp'

      #{definitions}
      STRING
    end

    # Returns the contents
    sig {returns(String)}
    def formatted_contents
      if defined?(CodeRay)
        CodeRay.scan(contents, :ruby).term
      else
        contents
      end
    end

    sig {params(declaration: QueryDeclaration).void}
    def generate(declaration)
      query = GraphQL::Query.new(declaration.schema, declaration.query_text)

      query.operations.each do |name, op_def|
        owner_type = case op_def.operation_type 
        when 'query'
          schema.query
        when'mutation'
          schema.mutation
        when'subscription'
          schema.subscription
        else
          Kernel.raise("Unknown operation type: #{op_def.type}")
        end

        ensure_constant_name(name)
        module_name = "#{declaration.container.name}::#{name}"
        root_type = generate_result_class(
          module_name,
          owner_type,
          op_def.selections,
          top_level: OperationDeclaration.new(
            declaration: declaration,
            operation_name: name,
          )
        )
      end
    end

    sig {params(definition: DefinedClass).void}
    def add_class(definition)
      raise "Already have class" if @classes.key?(definition.name)
      @classes[definition.name] = definition
    end

    sig {returns(GRAPHQL_SCHEMA)}
    def schema
      @schema
    end

    sig {params(name: String).void}
    def ensure_constant_name(name)
      return if name.match?(/\A[A-Z][a-zA-Z0-9_]+\z/)
      raise "You must use valid Ruby constant names for query names (got #{name})"
    end

    sig {params(enum_type: T.class_of(GraphQL::Schema::Enum)).returns(String)}
    def enum_for(enum_type)
      enum_class_name = @enums[enum_type.graphql_name]
      return enum_class_name if enum_class_name

      # TODO: sanitize the name
      klass_name = "#{schema.name}::#{enum_type.graphql_name}"
      add_class(EnumClass.new(name: klass_name, serialized_values: enum_type.values.keys))
      @enums[enum_type.graphql_name] = klass_name
    end

    sig do
      params(
        module_name: String,
        owner_type: T.untyped,
        selections: T::Array[T.untyped],
        top_level: T.nilable(OperationDeclaration)
      )
      .returns(TypedExpression)
    end
    private def generate_result_class(module_name, owner_type, selections, top_level: nil)
      methods = T.let([], T::Array[DefinedMethod])
      selections.each do |node|
        case node
        when GraphQL::Language::Nodes::Field
          # Get the result type for this particular selection
          field_name = node.name
          field_definition = owner_type.get_field(field_name)
          
          if field_definition.nil?
            field_definition = if owner_type == schema.query && (entry_point_field = schema.introspection_system.entry_point(name: field_name))
              is_introspection = true
              entry_point_field
            elsif (dynamic_field = schema.introspection_system.dynamic_field(name: field_name))
              is_introspection = true
              dynamic_field
            else
              raise "Invariant: no field for #{owner_type}.#{field_name}"
            end
          end

          input_name = node.alias || node.name
          next_name = "#{module_name}::#{camelize(input_name)}"
          return_type = sorbet_type(
            field_definition.type,
            node.selections,
            next_name,
            input_name
          )
          
          method_name = generate_method_name(underscore(input_name))
          methods.push(DefinedMethod.new(
            name: method_name, 
            signature: return_type.signature,
            body: return_type.converter,
          ))
        end
      end

      if top_level
        add_class(
          RootClass.new(
            name: module_name,
            schema: schema,
            operation_name: top_level.operation_name,
            query_container: top_level.declaration.container,
            defined_methods: methods
          )
        )
      else
        add_class(
          LeafClass.new(
            name: module_name,
            defined_methods: methods
          )
        )
      end

      TypedExpression.new(
        signature: module_name,
        converter: <<~STRING
          #{module_name}.new(raw_value)
        STRING
      )
    end

    sig do
      params(
        wrappers: T::Array[TypeWrapper],
        variable_name: String,
        array_wrappers: Integer,
        level: Integer,
        core_expression: String
      ).returns(String)
    end
    def build_expression(wrappers, variable_name, array_wrappers, level, core_expression)
      next_wrapper = wrappers.shift
      case next_wrapper
      when TypeWrapper::ARRAY
        array_wrappers -= 1
        next_variable_name = if array_wrappers == 0
          "raw_value"
        else
          "inner_value#{array_wrappers}"
        end

        indent(<<~STRING, level)
          #{variable_name}.map do |#{next_variable_name}|
            #{build_expression(wrappers, next_variable_name, array_wrappers, level + 1, core_expression)}
          end
        STRING
      when TypeWrapper::NILABLE
        break_word = level == 0 ? 'return' : 'next'
        indent(<<~STRING, level)
          #{break_word} if #{variable_name}.nil?
          #{build_expression(wrappers, variable_name, array_wrappers, level, core_expression)}
        STRING
      when nil
        if level == 0
          indent(core_expression.gsub(/raw_value/, variable_name), level)
        else
          indent(core_expression, level)
        end
      else
        T.absurd(next_wrapper)
      end
    end
  
    # Returns the TypedExpression object for this graphql type.
    sig do
      params(
        graphql_type: T.untyped,
        subselections: T::Array[T.untyped],
        next_module_name: String,
        input_name: String
      ).returns(TypedExpression)
    end
    def sorbet_type(graphql_type, subselections, next_module_name, input_name)
      # Unwrap the graphql type, but keep track of the wrappers that it had
      # so that we can build the sorbet signature and return expression.
      wrappers = T.let([], T::Array[TypeWrapper])
      fully_unwrapped_type = T.let(graphql_type, T.untyped)
  
      # Sorbet uses nullable wrappers, whereas GraphQL uses non-nullable wrappers.
      # This boolean is used to help with the conversion.
      skip_nilable = T.let(false, T::Boolean)
      array_wrappers = 0
  
      loop do
        if fully_unwrapped_type.non_null?
          fully_unwrapped_type = T.unsafe(fully_unwrapped_type).of_type
          skip_nilable = true
          next
        end
  
        wrappers << TypeWrapper::NILABLE if !skip_nilable
        skip_nilable = false
  
        if fully_unwrapped_type.list?
          wrappers << TypeWrapper::ARRAY
          array_wrappers += 1
          fully_unwrapped_type = T.unsafe(fully_unwrapped_type).of_type
          next
        end
  
        break
      end

      core_sorbet_type = unwrapped_graphql_type_to_sorbet_type(fully_unwrapped_type, subselections, next_module_name)
      
      signature = core_sorbet_type.signature
      variable_name = "raw_result[#{input_name.inspect}]"
      method_body = build_expression(wrappers.dup, variable_name, array_wrappers, 0, core_sorbet_type.converter)

      wrappers.reverse_each do |wrapper|
        case wrapper
        when TypeWrapper::ARRAY
          signature = "T::Array[#{signature}]"
        when TypeWrapper::NILABLE
          signature = "T.nilable(#{signature})"
        else
          T.absurd(wrapper)
        end
      end
  
      TypedExpression.new(
        signature: signature,
        converter: method_body
      )
    end

    sig {params(scalar_converter: ScalarConverter).returns(TypedExpression)}
    def sorbet_type_from_scalar_converter(scalar_converter)
      TypedExpression.new(
        signature: scalar_converter.sorbet_type,
        converter: <<~STRING.strip
          scalar_converter = GraphQLClient.find_scalar_converter(
            schema: #{scalar_converter.schema.name},
            graphql_type: #{scalar_converter.graphql_type}
          )

          scalar_converter.converter.call(raw_value)
        STRING
      )
    end

    sig do
      params(
        type_name: String,
        block: T.proc.returns(TypedExpression)
      ).returns(TypedExpression)
    end
    def converter_or_default(type_name, &block)
      converter = @scalars[type_name]
      return sorbet_type_from_scalar_converter(converter) if converter
      yield
    end
  
    # Given an (unwrapped) GraphQL type, returns the definition for the type to use
    # for the signature and method body.
    sig do
      params(
        graphql_type: T.untyped,
        subselections: T::Array[T.untyped],
        next_module_name: String,
      ).returns(TypedExpression)
    end
    def unwrapped_graphql_type_to_sorbet_type(graphql_type, subselections, next_module_name)
      if graphql_type == GraphQL::Types::Boolean
        TypedExpression.new(
          signature: "T::Boolean",
          converter: 'T.let(raw_value, T::Boolean)'
        )
      elsif graphql_type == GraphQL::Types::BigInt
        converter_or_default(T.unsafe(GraphQL::Types::BigInt).graphql_name) do
          TypedExpression.new(
            signature: "Integer",
            converter: 'T.let(raw_value, T.any(String, Integer)).to_i'
          )
        end
      elsif graphql_type == GraphQL::Types::ID
        converter_or_default('ID') do
          TypedExpression.new(
            signature: "String",
            converter: 'T.let(raw_value, String)'
          )
        end
      elsif graphql_type == GraphQL::Types::ISO8601Date
        converter_or_default(T.unsafe(GraphQL::Types::ISO8601Date).graphql_name) do
          TypedExpression.new(
            signature: "Date",
            converter: 'Date.iso8601(T.let(raw_value, String))'
          )
        end
      elsif graphql_type == GraphQL::Types::ISO8601DateTime
        converter_or_default(T.unsafe(GraphQL::Types::ISO8601DateTime).graphql_name) do
          TypedExpression.new(
            signature: "Time",
            converter: 'Time.iso8601(T.let(raw_value, String))'
          )
        end
      elsif graphql_type == GraphQL::Types::Int
        TypedExpression.new(
          signature: "Integer",
          converter: 'T.let(raw_value, Integer)'
        )
      elsif graphql_type == GraphQL::Types::Float
        TypedExpression.new(
          signature: "Float",
          converter: 'T.let(raw_value, Float)'
        )
      elsif graphql_type == GraphQL::Types::String
        TypedExpression.new(
          signature: "String",
          converter: 'T.let(raw_value, String)'
        )
      elsif graphql_type.is_a?(Class)
        if graphql_type < GraphQL::Schema::Enum
          klass_name = enum_for(graphql_type)
  
          TypedExpression.new(
            signature: klass_name,
            converter: "#{klass_name}.deserialize(T.let(raw_value, String))"
          )
        elsif graphql_type < GraphQL::Schema::Scalar
          converter_or_default(graphql_type.graphql_name) do
            TypedExpression.new(
              signature: T.unsafe(GraphQLClient::RAW_SCALAR_TYPE).name,
              converter: "T.let(raw_value, #{T.unsafe(GraphQLClient::RAW_SCALAR_TYPE).name})"
            )
          end
        elsif graphql_type < GraphQL::Schema::Member
          generate_result_class(
            next_module_name,
            graphql_type,
            subselections
          )
        else
          raise "Unknown GraphQL type: #{graphql_type.inspect}"
        end
      else
        raise "Unknown GraphQL type: #{graphql_type.inspect}"
      end
    end
  end
end