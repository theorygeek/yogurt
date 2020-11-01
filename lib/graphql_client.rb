# typed: strict
# frozen_string_literal: true

require 'zeitwerk'
loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect({ 'graphql_client' => 'GraphQLClient' })
loader.setup

module GraphQLClient; end
loader.eager_load
