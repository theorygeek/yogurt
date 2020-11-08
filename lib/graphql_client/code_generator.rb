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

      # Maps GraphQL enum name to class name
      @enums = T.let({}, T::Hash[String, String])

      # Maps GraphQL input type name to class name
      @input_types = T.let({}, T::Hash[String, String])
      @scalars = T.let(GraphQLClient.scalar_converters(schema), T::Hash[String, SCALAR_CONVERTER])
      @classes = T.let({}, T::Hash[String, DefinedClass])
    end

    sig {returns(String)}
    def contents
      definitions = DefinedClassSorter.new(classes.values)
        .sorted_classes
        .map {|definition| definition.to_ruby}
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
          operation_declaration: OperationDeclaration.new(
            declaration: declaration,
            operation_name: name,
            variables: op_def.variables
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
    def enum_class(enum_type)
      enum_class_name = @enums[enum_type.graphql_name]
      return enum_class_name if enum_class_name

      # TODO: sanitize the name
      klass_name = "#{schema.name}::#{enum_type.graphql_name}"
      add_class(EnumClass.new(name: klass_name, serialized_values: enum_type.values.keys))
      @enums[enum_type.graphql_name] = klass_name
    end

    sig {params(graphql_name: String).returns(String)}
    def input_class(graphql_name)
      input_class_name = @input_types[graphql_name]
      return input_class_name if input_class_name

      klass_name = "#{schema.name}::#{graphql_name}"
      graphql_type = schema.types[graphql_name]

      arguments = graphql_type.arguments.each_value.map do |argument|
        variable_definition(argument)
      end

      add_class(InputClass.new(name: klass_name, arguments: arguments))
      @input_types[graphql_name] = klass_name
    end

    sig do
      params(
        module_name: String,
        owner_type: T.untyped,
        selections: T::Array[T.untyped],
        operation_declaration: T.nilable(OperationDeclaration),
        dependencies: T::Array[String],
      )
      .returns(TypedOutput)
    end
    private def generate_result_class(module_name, owner_type, selections, operation_declaration: nil, dependencies: [])
      methods = T.let([], T::Array[DefinedMethod])
      next_dependencies = [module_name, *dependencies]
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
          return_type = generate_output_type(
            field_definition.type,
            node.selections,
            next_name,
            input_name,
            next_dependencies
          )
          
          method_name = generate_method_name(underscore(input_name))
          methods.push(DefinedMethod.new(
            name: method_name, 
            signature: return_type.signature,
            body: return_type.deserializer,
          ))
        end
      end

      if operation_declaration
        add_class(
          RootClass.new(
            name: module_name,
            schema: schema,
            operation_name: operation_declaration.operation_name,
            query_container: operation_declaration.declaration.container,
            defined_methods: methods,
            variables: operation_declaration.variables.map {|v| variable_definition(v)},
            dependencies: dependencies,
          )
        )
      else
        add_class(
          LeafClass.new(
            name: module_name,
            defined_methods: methods,
            dependencies: dependencies,
          )
        )
      end

      TypedOutput.new(
        signature: module_name,
        deserializer: <<~STRING
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
  
    # Returns the TypedOutput object for this graphql type.
    sig do
      params(
        graphql_type: T.untyped,
        subselections: T::Array[T.untyped],
        next_module_name: String,
        input_name: String,
        dependencies: T::Array[String]
      ).returns(TypedOutput)
    end
    def generate_output_type(graphql_type, subselections, next_module_name, input_name, dependencies)
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

      core_typed_expression = unwrapped_graphql_type_to_output_type(fully_unwrapped_type, subselections, next_module_name, dependencies)
      
      signature = core_typed_expression.signature
      variable_name = "raw_result[#{input_name.inspect}]"
      method_body = build_expression(wrappers.dup, variable_name, array_wrappers, 0, core_typed_expression.deserializer)

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
  
      TypedOutput.new(
        signature: signature,
        deserializer: method_body
      )
    end

    sig {params(scalar_converter: SCALAR_CONVERTER).returns(TypedOutput)}
    def output_type_from_scalar_converter(scalar_converter)
      name = scalar_converter.name
      if name.nil?
        raise "Expected scalar deserializer to be assigned to a constant"
      end

      TypedOutput.new(
        signature: scalar_converter.type_alias.name,
        deserializer: "#{name}.deserialize(raw_value)"
      )
    end

    sig do
      params(
        type_name: String,
        block: T.proc.returns(TypedOutput)
      ).returns(TypedOutput)
    end
    def deserializer_or_default(type_name, &block)
      deserializer = @scalars[type_name]
      return output_type_from_scalar_converter(deserializer) if deserializer
      yield
    end
  
    # Given an (unwrapped) GraphQL type, returns the definition for the type to use
    # for the signature and method body.
    sig do
      params(
        graphql_type: T.untyped,
        subselections: T::Array[T.untyped],
        next_module_name: String,
        dependencies: T::Array[String]
      ).returns(TypedOutput)
    end
    def unwrapped_graphql_type_to_output_type(graphql_type, subselections, next_module_name, dependencies)
      if graphql_type == GraphQL::Types::Boolean
        TypedOutput.new(
          signature: "T::Boolean",
          deserializer: 'T.let(raw_value, T::Boolean)'
        )
      elsif graphql_type == GraphQL::Types::BigInt
        deserializer_or_default(T.unsafe(GraphQL::Types::BigInt).graphql_name) do
          TypedOutput.new(
            signature: "Integer",
            deserializer: 'T.let(raw_value, T.any(String, Integer)).to_i'
          )
        end
      elsif graphql_type == GraphQL::Types::ID
        deserializer_or_default('ID') do
          TypedOutput.new(
            signature: "String",
            deserializer: 'T.let(raw_value, String)'
          )
        end
      elsif graphql_type == GraphQL::Types::ISO8601Date
        deserializer_or_default(T.unsafe(GraphQL::Types::ISO8601Date).graphql_name) do
          output_type_from_scalar_converter(Converters::Date)
        end
      elsif graphql_type == GraphQL::Types::ISO8601DateTime
        deserializer_or_default(T.unsafe(GraphQL::Types::ISO8601DateTime).graphql_name) do
          output_type_from_scalar_converter(Converters::Time)
        end
      elsif graphql_type == GraphQL::Types::Int
        TypedOutput.new(
          signature: "Integer",
          deserializer: 'T.let(raw_value, Integer)'
        )
      elsif graphql_type == GraphQL::Types::Float
        TypedOutput.new(
          signature: "Float",
          deserializer: 'T.let(raw_value, Float)'
        )
      elsif graphql_type == GraphQL::Types::String
        TypedOutput.new(
          signature: "String",
          deserializer: 'T.let(raw_value, String)'
        )
      elsif graphql_type.is_a?(Class)
        if graphql_type < GraphQL::Schema::Enum
          klass_name = enum_class(graphql_type)
          dependencies.push(klass_name)
  
          TypedOutput.new(
            signature: klass_name,
            deserializer: "#{klass_name}.deserialize(T.let(raw_value, String))"
          )
        elsif graphql_type < GraphQL::Schema::Scalar
          deserializer_or_default(graphql_type.graphql_name) do
            TypedOutput.new(
              signature: T.unsafe(GraphQLClient::SCALAR_TYPE).name,
              deserializer: "T.let(raw_value, #{T.unsafe(GraphQLClient::SCALAR_TYPE).name})"
            )
          end
        elsif graphql_type < GraphQL::Schema::Member
          generate_result_class(
            next_module_name,
            graphql_type,
            subselections,
            dependencies: dependencies
          )
        else
          raise "Unknown GraphQL type: #{graphql_type.inspect}"
        end
      else
        raise "Unknown GraphQL type: #{graphql_type.inspect}"
      end
    end

    sig {params(variable: T.any(GraphQL::Language::Nodes::VariableDefinition, GraphQL::Schema::Argument)).returns(VariableDefinition)}
    def variable_definition(variable)
      wrappers = T.let([], T::Array[TypeWrapper])
      fully_unwrapped_type = T.let(variable.type, T.untyped)

      skip_nilable = T.let(false, T::Boolean)
      array_wrappers = 0
  
      loop do
        non_null = fully_unwrapped_type.is_a?(GraphQL::Schema::NonNull) || fully_unwrapped_type.is_a?(GraphQL::Language::Nodes::NonNullType)
        if non_null
          fully_unwrapped_type = T.unsafe(fully_unwrapped_type).of_type
          skip_nilable = true
          next
        end
  
        wrappers << TypeWrapper::NILABLE if !skip_nilable
        skip_nilable = false
  
        list = fully_unwrapped_type.is_a?(GraphQL::Schema::List) || fully_unwrapped_type.is_a?(GraphQL::Language::Nodes::ListType)
        if list
          wrappers << TypeWrapper::ARRAY
          array_wrappers += 1
          fully_unwrapped_type = T.unsafe(fully_unwrapped_type).of_type
          next
        end
  
        break
      end

      core_input_type = unwrapped_graphql_type_to_input_type(fully_unwrapped_type)
      variable_name = underscore(variable.name).to_sym
      signature = core_input_type.signature
      serializer = core_input_type.serializer
      
      wrappers.reverse_each do |wrapper|
        case wrapper
        when TypeWrapper::NILABLE
          signature = "T.nilable(#{signature})"
          serializer = <<~STRING
            if raw_value
              #{indent(serializer, 1).strip}
            end
          STRING
        when TypeWrapper::ARRAY
          signature = "T::Array[#{signature}]"
          intermediate_name = "#{variable_name}#{array_wrappers}"
          serializer = serializer.gsub(/\braw_value\b/, intermediate_name)
          serializer = <<~STRING
            raw_value.map do |#{intermediate_name}|
              #{indent(serializer, 1).strip}
            end
          STRING
        else
          T.absurd(wrapper)
        end
      end

      serializer = serializer.gsub(/\braw_value\b/, variable_name.to_s)

      VariableDefinition.new(
        name: variable_name,
        graphql_name: variable.name,
        signature: signature,
        serializer: serializer.strip,
        dependency: core_input_type.dependency,
      )
    end

    sig {params(scalar_converter: SCALAR_CONVERTER).returns(TypedInput)}
    def input_type_from_scalar_converter(scalar_converter)
      name = scalar_converter.name
      if name.nil?
        raise "Expected scalar deserializer to be assigned to a constant"
      end

      TypedInput.new(
        signature: scalar_converter.type_alias.name,
        serializer: "#{name}.serialize(raw_value)",
      )
    end

    sig do
      params(
        type_name: String,
        block: T.proc.returns(TypedInput)
      ).returns(TypedInput)
    end
    def serializer_or_default(type_name, &block)
      deserializer = @scalars[type_name]
      return input_type_from_scalar_converter(deserializer) if deserializer
      yield
    end

    sig do
      params(graphql_type: T.untyped).returns(TypedInput)
    end
    def unwrapped_graphql_type_to_input_type(graphql_type)
      if graphql_type.is_a?(GraphQL::Language::Nodes::TypeName)
        graphql_type = schema.types[T.unsafe(graphql_type).name]
      end

      if graphql_type == GraphQL::Types::Boolean
        TypedInput.new(
          signature: "T::Boolean",
          serializer: "raw_value"
        )
      elsif graphql_type == GraphQL::Types::BigInt
        serializer_or_default(T.unsafe(GraphQL::Types::BigInt).graphql_name) do
          TypedInput.new(
            signature: "Integer",
            serializer: "raw_value"
          )
        end
      elsif graphql_type == GraphQL::Types::ID
        serializer_or_default('ID') do
          TypedInput.new(
            signature: "String",
            serializer: "raw_value"
          )
        end
      elsif graphql_type == GraphQL::Types::ISO8601Date
        serializer_or_default(T.unsafe(GraphQL::Types::ISO8601Date).graphql_name) do
          input_type_from_scalar_converter(Converters::Date)
        end
      elsif graphql_type == GraphQL::Types::ISO8601DateTime
        serializer_or_default(T.unsafe(GraphQL::Types::ISO8601DateTime).graphql_name) do
          input_type_from_scalar_converter(Converters::Time)
        end
      elsif graphql_type == GraphQL::Types::Int
        TypedInput.new(
          signature: "Integer",
          serializer: "raw_value"
        )
      elsif graphql_type == GraphQL::Types::Float
        TypedInput.new(
          signature: "Float",
          serializer: "raw_value"
        )
      elsif graphql_type == GraphQL::Types::String
        TypedInput.new(
          signature: "String",
          serializer: "raw_value"
        )
      elsif graphql_type.is_a?(Class)
        if graphql_type < GraphQL::Schema::Enum
          klass_name = enum_class(graphql_type)
  
          TypedInput.new(
            signature: klass_name,
            serializer: "raw_value.serialize",
            dependency: klass_name,
          )
        elsif graphql_type < GraphQL::Schema::Scalar
          serializer_or_default(graphql_type.graphql_name) do
            TypedInput.new(
              signature: T.unsafe(GraphQLClient::SCALAR_TYPE).name,
              serializer: "raw_value"
            )
          end
        elsif graphql_type < GraphQL::Schema::InputObject
          klass_name = input_class(T.unsafe(graphql_type).graphql_name)
          TypedInput.new(
            signature: klass_name,
            serializer: "raw_value.serialize",
            dependency: klass_name,
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