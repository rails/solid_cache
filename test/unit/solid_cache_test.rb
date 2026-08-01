# frozen_string_literal: true

require "test_helper"
require "concurrent"
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

  def test_expired_placeholder_payload_deserializes_as_expired_entry
    payload = @cache.send(
      :serialize_entry,
      ActiveSupport::Cache::Entry.new(nil, expires_in: -1)
    )

    entry = @cache.send(:deserialize_entry, payload)

    assert entry
    assert_predicate entry, :expired?
  end

  def test_concurrent_increment_on_missing_key_serializes_initial_creation
    key = SecureRandom.uuid
    barrier = Concurrent::CyclicBarrier.new(2)
    results = Queue.new
    errors = Queue.new

    threads = 2.times.map do
      Thread.new do
        cache = lookup_store(namespace: @namespace, expires_in: 60)

        barrier.wait
        results << cache.increment(key)
      rescue => error
        errors << error
      end
    end

    threads.each(&:join)

    thread_errors = []
    thread_errors << errors.pop until errors.empty?

    assert_predicate thread_errors, :empty?, <<~MSG
      expected no thread errors, got #{thread_errors.size}:
      #{thread_errors.map { |e| "#{e.class}: #{e.message}\n#{Array(e.backtrace).first(10).join("\n")}" }.join("\n\n")}
    MSG

    values = 2.times.map { results.pop }.sort
    assert_equal [1, 2], values
    assert_equal 2, @cache.read(key, raw: true).to_i
  end

  def test_concurrent_write_with_unless_exist_only_writes_once_for_missing_key
    key = SecureRandom.uuid
    barrier = Concurrent::CyclicBarrier.new(2)
    results = Queue.new
    errors = Queue.new

    payloads = [ "first", "second" ]

    threads = payloads.map do |payload|
      Thread.new(payload) do |value|
        cache = lookup_store(namespace: @namespace, expires_in: 60)

        barrier.wait
        results << cache.write(key, value, unless_exist: true)
      rescue => error
        errors << error
      end
    end

    threads.each(&:join)

    thread_errors = []
    thread_errors << errors.pop until errors.empty?

    assert_predicate thread_errors, :empty?, <<~MSG
      expected no thread errors, got #{thread_errors.size}:
      #{thread_errors.map { |e| "#{e.class}: #{e.message}\n#{Array(e.backtrace).first(10).join("\n")}" }.join("\n\n")}
    MSG

    values = 2.times.map { results.pop }
    assert_equal 1, values.count(true)
    assert_equal 1, values.count(false)
    assert_includes [ "first", "second" ], @cache.read(key)
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
