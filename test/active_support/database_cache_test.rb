require "test_helper"
require_relative "../behaviors"
require "active_support/testing/method_call_assertions"

class ActiveSupport::DatabaseCacheTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::MethodCallAssertions
  include CacheStoreBehavior
  include CacheStoreVersionBehavior
  include CacheStoreCoderBehavior
  include LocalCacheBehavior
  include CacheIncrementDecrementBehavior
  include CacheInstrumentationBehavior
  include ConnectionPoolBehavior
  include EncodedKeyCacheBehavior

  def lookup_store(options = {})
    ActiveSupport::Cache.lookup_store(:database_cache_store, { namespace: @namespace }.merge(options))
  end

  setup do
    @cache = nil
    @namespace = "test-#{SecureRandom.hex}"

    @cache = lookup_store(expires_in: 60)
    # @cache.logger = Logger.new($stdout)  # For test debugging

    # For LocalCacheBehavior tests
    @peek = lookup_store(expires_in: 60)
  end
end
