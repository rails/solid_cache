require "test_helper"
require_relative "../behaviors"
require "active_support/testing/method_call_assertions"

class ActiveSupport::DatabaseCacheTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::MethodCallAssertions
  include CacheStoreBehavior
  include CacheStoreVersionBehavior
  include CacheStoreCoderBehavior
  # include LocalCacheBehavior
  include CacheIncrementDecrementBehavior
  include CacheInstrumentationBehavior
  # include EncodedKeyCacheBehavior

  def lookup_store(options = {})
    ActiveSupport::Cache.lookup_store(:database_cache_store, options)
  end

  setup do
    @cache = ActiveSupport::Cache::DatabaseCacheStore.new
  end
end
