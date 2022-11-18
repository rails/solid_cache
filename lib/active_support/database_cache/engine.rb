require "active_support"
require "active_support/cache"
require "active_support/database_cache/version"
require "zeitwerk"

loader = Zeitwerk::Loader.new
loader.inflector = Zeitwerk::GemInflector.new(__FILE__)
loader.push_dir(File.expand_path("../..", __dir__))
loader.setup

module ActiveSupport
  module DatabaseCache
    class Engine < ::Rails::Engine
      isolate_namespace ActiveSupport::DatabaseCache
    end
  end
end
