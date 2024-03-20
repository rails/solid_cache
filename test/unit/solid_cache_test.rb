# frozen_string_literal: true

require "test_helper"
require_relative "behaviors"
require "active_support/testing/method_call_assertions"

class SolidCacheTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::MethodCallAssertions

  if Rails::VERSION::MAJOR == 7 && Rails::VERSION::MINOR == 0
    include CacheStoreBehavior
    include CacheStoreVersionBehavior
    include CacheStoreCoderBehavior
    include LocalCacheBehavior
    include CacheIncrementDecrementBehavior
    include CacheInstrumentationBehavior
    include EncodedKeyCacheBehavior
  else
    include CacheStoreBehavior
    include CacheStoreVersionBehavior
    include CacheStoreCoderBehavior
    include CacheStoreCompressionBehavior
    include CacheStoreFormatVersionBehavior
    include CacheStoreSerializerBehavior
    include LocalCacheBehavior
    include CacheIncrementDecrementBehavior
    include CacheInstrumentationBehavior
    include CacheLoggingBehavior
    include EncodedKeyCacheBehavior
  end

  setup do
    @cache = nil
    @namespace = "test-#{SecureRandom.hex}"

    @cache = lookup_store(expires_in: 60)
    # @cache.logger = Logger.new($stdout)  # For test debugging

    # For LocalCacheBehavior tests
    @peek = lookup_store(expires_in: 60)
  end

  test "max key bytesize" do
    cache = lookup_store(max_key_bytesize: 100)
    assert_equal 100, cache.send(:normalize_key, SecureRandom.hex(200), {}).bytesize
  end

  test "loads defaults from config/solid_cache.yml" do
    cache = lookup_store
    assert_equal 3600, cache.primary_cluster.max_age
  end

  test "cache options override defaults" do
    cache = lookup_store(max_age: 7200)
    assert_equal 7200, cache.primary_cluster.max_age
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
    wait_for_background_tasks(@cache)
    stub_matcher = ActiveRecord::Base.connection.class.any_instance
    stub_matcher.stubs(:exec_query).raises(ActiveRecord::StatementInvalid)
    stub_matcher.stubs(:internal_exec_query).raises(ActiveRecord::StatementInvalid)
    stub_matcher.stubs(:exec_delete).raises(ActiveRecord::StatementInvalid)
    yield lookup_store(namespace: @namespace)
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
    wait_for_background_tasks(@cache)
    stub_matcher = ActiveRecord::Base.connection.class.any_instance
    stub_matcher.stubs(:exec_query).raises(ActiveRecord::StatementInvalid)
    stub_matcher.stubs(:internal_exec_query).raises(ActiveRecord::StatementInvalid)
    stub_matcher.stubs(:exec_delete).raises(ActiveRecord::StatementInvalid)
    yield lookup_store(namespace: @namespace,
      error_handler: ->(method:, returning:, exception:) { raise exception })
  ensure
    stub_matcher.unstub(:exec_query)
    stub_matcher.unstub(:internal_exec_query)
    stub_matcher.unstub(:exec_delete)
  end
end
