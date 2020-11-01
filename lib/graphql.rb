# typed: strict
require 'zeitwerk'
loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect({'graphql' => 'GraphQL', 'version' => 'VERSION'})
loader.setup

module GraphQL; end

loader.eager_load