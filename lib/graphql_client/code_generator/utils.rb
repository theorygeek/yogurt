# typed: strict
# frozen_string_literal: true

module GraphQLClient
  class CodeGenerator
    module Utils
      extend T::Sig

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

      sig {params(string: String, amount: Integer).returns(String)}
      def indent(string, amount)
        string.split("\n").map {|line| ('  ' * amount) + line}.join("\n")
      end

      sig {params(desired_name: String).returns(Symbol)}
      def generate_method_name(desired_name)
        base_desired_name = desired_name
        escaping_level = 0
        
        while PROTECTED_NAMES.include?(desired_name)
          escaping_level += 1
          desired_name = "#{base_desired_name}#{'_' * escaping_level}"
        end
  
        desired_name.to_sym
      end
  
      sig {params(methods: T::Array[DefinedMethod]).returns(String)}
      def generate_pretty_print(methods)
        inspect_lines = methods.map do |dm|
          <<~STRING
            p.text(#{dm.name.to_s.inspect})
            p.text(': ')
            p.pp(#{dm.name})
          STRING
        end
  
        inspect_lines = inspect_lines.join(<<~STRING)
          p.comma_breakable
  
        STRING
  
        <<~STRING
          sig {override.params(p: PP::PPMethods).void}
          def pretty_print(p)
            p.object_group(self) do
              p.breakable
  
              #{indent(inspect_lines, 2).strip}
            end
          end
        STRING
      end
    end
  end
end