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
    assert_equal 3600, cache.max_age
  end

  test "cache options override defaults" do
    cache = lookup_store(max_age: 7200)
    assert_equal 7200, cache.max_age
  end

  def test_write_with_unless_exist
    assert_equal true, @cache.write("foo", 1)
    assert_equal false, @cache.write("foo", 1, unless_exist: true)
  end

  def test_write_expired_value_with_unless_exist
    assert_equal true, @cache.write(1, "aaaa", expires_in: 1.second)
    travel 2.seconds
    assert_equal true, @cache.write(1, "bbbb", expires_in: 1.second, unless_exist: true)
  end

  test "concurrent writes with unless_exist to a missing key" do
    10.times do |i|
      key = "foo#{i}"
      results = concurrently { @cache.write(key, 1, unless_exist: true) }

      assert_equal 1, results.count(true)
      assert_equal 7, results.count(false)
      assert_equal 1, @cache.read(key)
    end
  end

  test "concurrent increments of a missing key" do
    10.times do |i|
      key = "foo#{i}"
      results = concurrently { @cache.increment(key) }

      assert_equal (1..8).to_a, results.sort
      assert_equal 8, @cache.read(key)
    end
  end

  private
    def concurrently(&block)
      ready = Queue.new
      start = Queue.new
      threads = 8.times.map do
        Thread.new do
          ready << true
          start.pop
          Rails.application.executor.wrap(&block)
        end
      end

      8.times { ready.pop }
      8.times { start << true }
      threads.map(&:value)
    ensure
      threads&.each(&:kill)
      threads&.each(&:join)
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
    emulating_timeouts do
      yield lookup_store(namespace: @namespace)
    end
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
    emulating_timeouts do
      yield lookup_store(namespace: @namespace,
        error_handler: ->(method:, returning:, exception:) { raise exception })
    end
  end
end
