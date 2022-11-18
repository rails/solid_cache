require "active_support"
require "active_support/cache"
require "active_support/database_cache/version"

module ActiveSupport
  module DatabaseCache
    class Engine < ::Rails::Engine
      isolate_namespace ActiveSupport::DatabaseCache
    end
  end
end
