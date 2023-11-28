# typed: strict
# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'yogurt/version'

Gem::Specification.new do |spec|
  spec.name = "yogurt"
  spec.version = Yogurt::VERSION
  spec.authors = ["Ryan Foster"]
  spec.email = ["theorygeek@gmail.com"]

  spec.summary = <<~STRING
    GraphQL client with Sorbet typing.
  STRING

  spec.homepage = "https://github.com/theorygeek/yogurt"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "https://rubygems.org"

    spec.metadata["homepage_uri"] = spec.homepage
    spec.metadata["source_code_uri"] = spec.homepage
    spec.metadata["changelog_uri"] = "https://github.com/theorygeek/yogurt/blob/master/CHANGELOG.md"
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject {|f| f.match(%r{^(test|spec|features)/})}
  end

  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) {|f| File.basename(f)}
  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 2.6"

  spec.add_dependency('graphql')
  spec.add_dependency('sorbet-runtime')
  spec.add_dependency('zeitwerk')

  spec.add_development_dependency('benchmark-ips')
  spec.add_development_dependency('bundler')
  spec.add_development_dependency('pry')
  spec.add_development_dependency('pry-byebug')
  spec.add_development_dependency('rake', '~> 13.0')
  spec.add_development_dependency('rspec', '~> 3.0')
  spec.add_development_dependency('rubocop', '~> 0.92')
  spec.add_development_dependency('rubocop-sorbet', '~> 0.5')
  spec.add_development_dependency('sorbet', '~> 0.5')
  spec.add_development_dependency('tapioca')
end
