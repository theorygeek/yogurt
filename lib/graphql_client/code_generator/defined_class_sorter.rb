# typed: strict
# frozen_string_literal: true

require 'tsort'
module GraphQLClient
  class CodeGenerator
    class DefinedClassSorter
      extend T::Sig
      include TSort

      sig {params(classes: T::Array[DefinedClass]).void}
      def initialize(classes)
        @classes = T.let(
          classes.map {|k| [k.name, k]}.to_h,
          T::Hash[String, DefinedClass],
        )
      end

      sig {returns(T::Array[DefinedClass])}
      def sorted_classes
        tsort
      end

      sig {params(block: T.proc.params(arg0: DefinedClass).void).void}
      private def tsort_each_node(&block)
        @classes.keys.sort.each do |key|
          yield(@classes[key])
        end
      end

      sig do
        params(
          input_class: DefinedClass,
          block: T.proc.params(arg0: DefinedClass).void,
        ).void
      end
      private def tsort_each_child(input_class, &block)
        input_class.dependencies.sort.each do |name|
          yield(@classes.fetch(name))
        end
      end
    end
  end
end
