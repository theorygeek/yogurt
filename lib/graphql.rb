require 'zeitwerk'
loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect({'graphql' => 'GraphQL'})
loader.setup

module GraphQL; end

loader.eager_load