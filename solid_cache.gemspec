require_relative "lib/solid_cache/version"

Gem::Specification.new do |spec|
  spec.name        = "solid_cache"
  spec.version     = SolidCache::VERSION
  spec.authors     = [ "Donal McBreen" ]
  spec.email       = [ "donal@37signals.com" ]
  spec.homepage    = "http://github.com/basecamp/solid_cache"
  spec.summary     = "A database backed ActiveSupport::Cache::Store"
  spec.description = "A database backed ActiveSupport::Cache::Store"
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "http://github.com/basecamp/solid_cache"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 7"
  spec.add_development_dependency "debug"
  spec.add_development_dependency "mocha"
end
