# typed: strict
# frozen_string_literal: true

module GraphQLClient
  class CodeGenerator
    extend T::Sig

    RAW_TYPE = T.let("T.any(::String, T::Boolean, ::Numeric)", String)

    sig {returns(T::Hash[String, String])}
    attr_reader :classes

    sig {params(schema: GRAPHQL_SCHEMA).void}
    def initialize(schema)
      @schema = T.let(schema, GRAPHQL_SCHEMA)
      @enums = T.let({}, T::Hash[String, String])
      @scalars = T.let({}, T::Hash[String, ScalarConverter])
      @classes = T.let({}, T::Hash[String, String])
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
        module_name = "#{schema.name}::#{name}"
        root_type = generate_result_class(
          module_name,
          owner_type,
          op_def.selections,
          top_level: true
        )

        # TBD.
      end
    end

    sig {params(class_name: String, definition: String).void}
    def add_class(class_name, definition)
      raise "Already have class" if @classes.key?(class_name)
      @classes[class_name] = definition
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
      sorbet_enum = @enums[enum_type.graphql_name]
      return sorbet_enum if sorbet_enum

      # Generate a new enum definition
      # TODO: sanitize the name
      klass_name = "#{schema.name}::#{enum_type.graphql_name}"

      definitions = enum_type.values.map do |name|
        # TODO: sanitize the name
        "#{name} = new(#{name.inspect})"
      end

      add_class(klass_name, <<~STRING)
        class #{klass_name} < T::Enum
          enums do
            #{indent(definitions.join("\n"), 2).strip}
          end
        end
      STRING

      @enums[enum_type.graphql_name] = klass_name
    end

    sig {params(camel_cased_word: String).returns(String)}
    def underscore(camel_cased_word)
      return camel_cased_word unless /[A-Z-]|::/.match?(camel_cased_word)
      word = camel_cased_word.to_s.gsub("::", "/")
      word.gsub!(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2')
      word.gsub!(/([a-z\d])([A-Z])/, '\1_\2')
      word.tr!("-", "_")
      word.downcase!
      word
    end

    sig {params(term: String).returns(String)}
    def camelize(term)
      string = term.to_s
      string = string.sub(/^[a-z\d]*/) { |match| match.capitalize }
      string.gsub!(/(?:_|(\/))([a-z\d]*)/i) { "#{$1}#{$2.capitalize}" }
      string.gsub!("/", "::")
      string
    end

    sig do
      params(
        module_name: String,
        owner_type: T.untyped,
        selections: T::Array[T.untyped],
        top_level: T::Boolean
      )
      .returns(SorbetType)
    end
    private def generate_result_class(module_name, owner_type, selections, top_level: false)
      methods = selections.map do |node|
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
          
          method_name = underscore(input_name)

          indent(<<~STRING, 1)
            sig {returns(#{return_type.signature})}
            def #{method_name}
              #{indent(return_type.converter, 1).strip}
            end
          STRING
        end
      end

      if top_level
        add_class(module_name, <<~STRING)
          class #{module_name}
            extend T::Sig
            include GraphQLClient::QueryResult
            include GraphQLClient::ErrorResult

            sig {params(result: T::Hash[String, T.untyped]).returns(T.any(T.attached_class, GraphQLClient::ErrorResult))}
            def self.from_result(result)
              data = result['data']
              if data
                new(data, result['errors'])
              else
                GraphQLClient::ErrorResult::OnlyErrors.new(result['errors'])
              end
            end

            sig {params(data: T::Hash[String, T.untyped], errors: T.nilable(T::Hash[String, T.untyped])).void}
            def initialize(data, errors)
              @result = T.let(data, T::Hash[String, T.untyped])
              @errors = T.let(errors, T.nilable(T::Hash[String, T.untyped]))
            end

            sig {override.returns(T.nilable(T::Hash[String, T.untyped]))}
            def __raw_result
              @result
            end

            sig {override.returns(T.nilable(T::Array[T::Hash[String, T.untyped]]))}
            def __errors
              @errors
            end

            #{methods.join("\n\n").strip}
          end
        STRING
      else
        add_class(module_name, <<~STRING)
          class #{module_name}
            extend T::Sig
            include GraphQLClient::QueryResult

            sig {params(result: T::Hash[String, T.untyped]).void}
            def initialize(result)
              @result = T.let(result, T::Hash[String, T.untyped])
            end

            sig {override.returns(T.nilable(T::Hash[String, T.untyped]))}
            def __raw_result
              @result
            end

            #{methods.join("\n\n").strip}
          end
        STRING
      end

      SorbetType.new(
        signature: module_name,
        converter: <<~STRING
          #{module_name}.new(raw_value)
        STRING
      )
    end

    sig {params(string: String, amount: Integer).returns(String)}
    def indent(string, amount)
      string.split("\n").map {|line| ('  ' * amount) + line}.join("\n")
    end

    sig do
      params(
        wrappers: T::Array[SorbetTypeWrapper],
        variable_name: String,
        array_wrappers: Integer,
        level: Integer,
        core_expression: String
      ).returns(String)
    end
    def build_expression(wrappers, variable_name, array_wrappers, level, core_expression)
      next_wrapper = wrappers.shift
      case next_wrapper
      when SorbetTypeWrapper::ARRAY
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
      when SorbetTypeWrapper::NILABLE
        break_word = level == 0 ? 'return' : 'next'
        indent(<<~STRING, level)
          #{break_word} if #{variable_name}.nil?
          #{build_expression(wrappers, variable_name, array_wrappers, level, core_expression)}
        STRING
      when nil
        if level == 0
          indent(<<~STRING, level)
            raw_value = #{variable_name}
            #{core_expression}
          STRING
        else
          indent(core_expression, level)
        end
      else
        T.absurd(next_wrapper)
      end
    end

    class SorbetTypeWrapper < T::Enum
      enums do
        NILABLE = new
        ARRAY = new
      end
    end
  
    # Returns the SorbetType object for this graphql type.
    sig do
      params(
        graphql_type: T.untyped,
        subselections: T::Array[T.untyped],
        next_module_name: String,
        input_name: String
      ).returns(SorbetType)
    end
    def sorbet_type(graphql_type, subselections, next_module_name, input_name)
      # Unwrap the graphql type, but keep track of the wrappers that it had
      # so that we can build the sorbet signature and return expression.
      wrappers = T.let([], T::Array[SorbetTypeWrapper])
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
  
        wrappers << SorbetTypeWrapper::NILABLE if !skip_nilable
        skip_nilable = false
  
        if fully_unwrapped_type.list?
          wrappers << SorbetTypeWrapper::ARRAY
          array_wrappers += 1
          fully_unwrapped_type = T.unsafe(fully_unwrapped_type).of_type
          next
        end
  
        break
      end

      core_sorbet_type = unwrapped_graphql_type_to_sorbet_type(fully_unwrapped_type, subselections, next_module_name)
      
      signature = core_sorbet_type.signature
      variable_name = "@result[#{input_name.inspect}]"
      method_body = build_expression(wrappers.dup, variable_name, array_wrappers, 0, core_sorbet_type.converter)

      wrappers.reverse_each do |wrapper|
        case wrapper
        when SorbetTypeWrapper::ARRAY
          signature = "T::Array[#{signature}]"
        when SorbetTypeWrapper::NILABLE
          signature = "T.nilable(#{signature})"
        else
          T.absurd(wrapper)
        end
      end
  
      SorbetType.new(
        signature: signature,
        converter: method_body
      )
    end

    class SorbetType < T::Struct
      # The signature to put in the sorbet type
      const :signature, String

      # Converter function to use for the return result.
      # This assumes that a local variable named `raw_value` has the
      # value to be converted.
      const :converter, String
    end

    sig {params(scalar_converter: ScalarConverter).returns(SorbetType)}
    def sorbet_type_from_scalar_converter(scalar_converter)
      SorbetType.new(
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
        block: T.proc.returns(SorbetType)
      ).returns(SorbetType)
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
      ).returns(SorbetType)
    end
    def unwrapped_graphql_type_to_sorbet_type(graphql_type, subselections, next_module_name)
      if graphql_type == GraphQL::Types::Boolean
        SorbetType.new(
          signature: "T::Boolean",
          converter: 'T.let(raw_value, T::Boolean)'
        )
      elsif graphql_type == GraphQL::Types::BigInt
        converter_or_default(T.unsafe(GraphQL::Types::BigInt).graphql_name) do
          SorbetType.new(
            signature: "::Integer",
            converter: 'T.let(raw_value, T.any(::String, ::Integer)).to_i'
          )
        end
      elsif graphql_type == GraphQL::Types::ID
        converter_or_default('ID') do
          SorbetType.new(
            signature: "::String",
            converter: 'T.let(raw_value, ::String)'
          )
        end
      elsif graphql_type == GraphQL::Types::ISO8601Date
        converter_or_default(T.unsafe(GraphQL::Types::ISO8601Date).graphql_name) do
          SorbetType.new(
            signature: "::Date",
            converter: '::Date.iso8601(T.let(raw_value, ::String))'
          )
        end
      elsif graphql_type == GraphQL::Types::ISO8601DateTime
        converter_or_default(T.unsafe(GraphQL::Types::ISO8601DateTime).graphql_name) do
          SorbetType.new(
            signature: "::Time",
            converter: '::Time.iso8601(T.let(raw_value, ::String))'
          )
        end
      elsif graphql_type == GraphQL::Types::Int
        SorbetType.new(
          signature: "::Integer",
          converter: 'T.let(raw_value, ::Integer)'
        )
      elsif graphql_type == GraphQL::Types::Float
        SorbetType.new(
          signature: "::Float",
          converter: 'T.let(raw_value, ::Float)'
        )
      elsif graphql_type == GraphQL::Types::String
        SorbetType.new(
          signature: "::String",
          converter: 'T.let(raw_value, ::String)'
        )
      elsif graphql_type.is_a?(Class)
        if graphql_type < GraphQL::Schema::Enum
          klass_name = enum_for(graphql_type)
  
          SorbetType.new(
            signature: klass_name,
            converter: "#{klass_name}.deserialize(T.let(raw_value, ::String))"
          )
        elsif graphql_type < GraphQL::Schema::Scalar
          converter_or_default(graphql_type.graphql_name) do
            SorbetType.new(
              signature: RAW_TYPE,
              converter: "T.let(raw_value, #{RAW_TYPE})"
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