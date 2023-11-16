require "test_helper"
require "active_support/testing/method_call_assertions"

class SolidCache::ExecutionTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @cache = nil
    @namespace = "test-#{SecureRandom.hex}"

    @cache = lookup_store(expiry_batch_size: 2, shards: nil)
  end

  def test_async_errors_are_reported
    error_subscriber = ErrorSubscriber.new
    Rails.error.subscribe(error_subscriber)

    @cache.primary_cluster.send(:async) do
      raise "Boom!"
    end

    sleep 0.1

    assert_equal 1, error_subscriber.errors.count
    assert_equal "Boom!", error_subscriber.errors.first[0].message
    assert_equal({ context: {}, handled: false, level: :error, source: "application.active_support" }, error_subscriber.errors.first[1])
  ensure
    Rails.error.unsubscribe(error_subscriber) if Rails.error.respond_to?(:unsubscribe)
  end

  def test_active_record_instrumention
    instrumented_cache = lookup_store
    uninstrumented_cache = lookup_store(active_record_instrumentation: false)

    calls = 0
    callback = ->(*args) { calls += 1 }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      assert_changes -> { calls } do
        instrumented_cache.read("foo")
      end
      assert_changes -> { calls } do
        instrumented_cache.write("foo", "bar")
      end
      assert_no_changes -> { calls } do
        uninstrumented_cache.read("foo")
      end
      assert_no_changes -> { calls } do
        uninstrumented_cache.write("foo", "bar")
      end
    end
  end

  def test_active_record_instrumention_expiry
    instrumented_cache = lookup_store(expiry_batch_size: 2)
    uninstrumented_cache = lookup_store(active_record_instrumentation: false, expiry_batch_size: 2)
    calls = 0
    callback = ->(*args) {
      calls += 1
    }

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      # Warm up the connections as they may log before instrumenation can be disabled
      uninstrumented_cache.write("foo", "bar")
      uninstrumented_cache.write("foo", "bar")
      uninstrumented_cache.write("foo", "bar")
      sleep 0.1

      assert_no_changes -> { calls } do
        uninstrumented_cache.write("foo", "bar")
        uninstrumented_cache.write("foo", "bar")
        uninstrumented_cache.write("foo", "bar")
        sleep 0.1
      end
    end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      # Warm up the connections as they may log before instrumenation can be disabled
      instrumented_cache.write("foo", "bar")
      instrumented_cache.write("foo", "bar")
      instrumented_cache.write("foo", "bar")
      sleep 0.1

      assert_changes -> { calls } do
        instrumented_cache.write("foo", "bar")
        instrumented_cache.write("foo", "bar")
        instrumented_cache.write("foo", "bar")
        sleep 0.1
      end
    end
  end

  unless ENV["NO_CONNECTS_TO"]
    def test_no_connections_uninstrumented
      ActiveRecord::ConnectionAdapters::ConnectionPool.any_instance.stubs(:connection).raises(ActiveRecord::StatementInvalid)

      cache = lookup_store(expires_in: 60, cluster: { shards: [ :primary_shard_one, :primary_shard_two ] }, active_record_instrumentation: false)

      assert_equal false, cache.write("1", "fsjhgkjfg")
      assert_nil cache.read("1")
      assert_nil cache.increment("1")
      assert_nil cache.decrement("1")
      assert_equal false, cache.delete("1")
      assert_equal({}, cache.read_multi("1", "2", "3"))
      assert_equal false, cache.write_multi("1" => "a", "2" => "b", "3" => "c")
    end

    def test_no_connections_instrumented
      ActiveRecord::ConnectionAdapters::ConnectionPool.any_instance.stubs(:connection).raises(ActiveRecord::StatementInvalid)

      cache = lookup_store(expires_in: 60, cluster: { shards: [ :primary_shard_one, :primary_shard_two ] })

      assert_equal false, cache.write("1", "fsjhgkjfg")
      assert_nil cache.read("1")
      assert_nil cache.increment("1")
      assert_nil cache.decrement("1")
      assert_equal false, cache.delete("1")
      assert_equal({}, cache.read_multi("1", "2", "3"))
      assert_equal false, cache.write_multi("1" => "a", "2" => "b", "3" => "c")
    end
  end

  class ErrorSubscriber
    attr_reader :errors

    def initialize
      @errors = []
    end

    def report(error, handled:, severity:, context:, source: nil)
      errors << [ error, { context: context, handled: handled, level: severity, source: source } ]
    end
  end
end
