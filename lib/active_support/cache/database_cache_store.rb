require "active_support/database_cache"

module ActiveSupport
  module Cache
    DatabaseCacheStore = DatabaseCache::Store
  end
end
