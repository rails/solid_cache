require_relative "lib/active_support/database_cache/version"

Gem::Specification.new do |spec|
  spec.name        = "active_support-database_cache"
  spec.version     = ActiveSupport::DatabaseCache::VERSION
  spec.authors     = ["Donal McBreen"]
  spec.email       = ["donal@basecamp.com"]
  spec.homepage    = "http://github.com/basecamp/active_support-database_cache"
  spec.summary     = "Database backed ActiveSupport cache store"
  spec.description = "Database backed ActiveSupport cache store"
  spec.license     = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the "allowed_push_host"
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "http://github.com/basecamp/active_support-database_cache"
  spec.metadata["changelog_uri"] = "http://github.com/basecamp/active_support-database_cache/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 7.0.4"
  spec.add_development_dependency "debug"
end
