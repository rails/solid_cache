# frozen_string_literal: true

require "test_helper"
require_relative "behaviors"
require "active_support/testing/method_call_assertions"

class SolidCacheTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::MethodCallAssertions
  include CacheStoreBehavior
  include CacheStoreVersionBehavior
  include CacheStoreFormatVersionBehavior
  include CacheStoreCoderBehavior
  include LocalCacheBehavior
  include CacheIncrementDecrementBehavior
  include CacheInstrumentationBehavior
  include EncodedKeyCacheBehavior

  setup do
    @cache = nil
    @namespace = "test-#{SecureRandom.hex}"

    @cache = lookup_store(expires_in: 60)
    # @cache.logger = Logger.new($stdout)  # For test debugging

    # For LocalCacheBehavior tests
    @peek = lookup_store(expires_in: 60)
  end

  test "each_shard" do
    shards = SolidCache.each_shard.map { SolidCache::Record.current_shard }
    if ENV["NO_CONNECTS_TO"]
      assert_equal [ :default ], shards
    else
      assert_equal [ :default, :primary_shard_one, :primary_shard_two, :secondary_shard_one, :secondary_shard_two ], shards
    end
  end

  test "max key bytesize" do
    cache = lookup_store(max_key_bytesize: 100)
    assert_equal 100, cache.send(:normalize_key, SecureRandom.hex(200), {}).bytesize
  end
end

class SolidCacheFailsafeTest < ActiveSupport::TestCase
  include FailureSafetyBehavior

  setup do
    @cache = nil
    @namespace = "test-#{SecureRandom.hex}"

    @cache = lookup_store(expires_in: 60)
    # @cache.logger = Logger.new($stdout)  # For test debugging

    # For LocalCacheBehavior tests
    @peek = lookup_store(expires_in: 60)
  end

  def emulating_unavailability
    stub_matcher = ActiveRecord::Base.connection.class.any_instance
    stub_matcher.stubs(:exec_query).raises(ActiveRecord::StatementInvalid)
    stub_matcher.stubs(:internal_exec_query).raises(ActiveRecord::StatementInvalid)
    stub_matcher.stubs(:exec_delete).raises(ActiveRecord::StatementInvalid)
    yield ActiveSupport::Cache::SolidCacheStore.new(namespace: @namespace)
  ensure
    stub_matcher.unstub(:exec_query)
    stub_matcher.unstub(:internal_exec_query)
    stub_matcher.unstub(:exec_delete)
  end
end

class SolidCacheRaisingTest < ActiveSupport::TestCase
  include FailureRaisingBehavior

  setup do
    @cache = nil
    @namespace = "test-#{SecureRandom.hex}"

    @cache = lookup_store(expires_in: 60)
    # @cache.logger = Logger.new($stdout)  # For test debugging

    # For LocalCacheBehavior tests
    @peek = lookup_store(expires_in: 60)
  end

  def emulating_unavailability
    stub_matcher = ActiveRecord::Base.connection.class.any_instance
    stub_matcher.stubs(:exec_query).raises(ActiveRecord::StatementInvalid)
    stub_matcher.stubs(:internal_exec_query).raises(ActiveRecord::StatementInvalid)
    stub_matcher.stubs(:exec_delete).raises(ActiveRecord::StatementInvalid)
    yield ActiveSupport::Cache::SolidCacheStore.new(namespace: @namespace,
      error_handler: ->(method:, returning:, exception:) { raise exception })
  ensure
    stub_matcher.unstub(:exec_query)
    stub_matcher.unstub(:internal_exec_query)
    stub_matcher.unstub(:exec_delete)
  end
end
