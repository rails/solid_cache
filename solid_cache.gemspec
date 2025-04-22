# frozen_string_literal: true

require_relative "lib/solid_cache/version"

Gem::Specification.new do |spec|
  spec.name        = "solid_cache"
  spec.version     = SolidCache::VERSION
  spec.authors     = [ "Donal McBreen" ]
  spec.email       = [ "donal@37signals.com" ]
  spec.homepage    = "http://github.com/rails/solid_cache"
  spec.summary     = "A database backed ActiveSupport::Cache::Store"
  spec.description = "A database backed ActiveSupport::Cache::Store"
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "http://github.com/rails/solid_cache"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  rails_version = ">= 7.2"
  spec.add_dependency "activerecord", rails_version
  spec.add_dependency "activejob", rails_version
  spec.add_dependency "railties", rails_version
  spec.add_development_dependency "debug"
  spec.add_development_dependency "mocha"
  spec.add_development_dependency "msgpack"
end
