# typed: strict
# frozen_string_literal: true

require 'pry'
require 'sorbet-runtime'
require 'zeitwerk'

module GraphQLClient; end

loader = Zeitwerk::Loader.new
loader.inflector.inflect({ 
  'graphql_client' => 'GraphQLClient',
  'version' => 'VERSION',
})
loader.push_dir(__dir__)
loader.setup
