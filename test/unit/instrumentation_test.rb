require "test_helper"
require "active_support/testing/method_call_assertions"

class SolidCache::ExpiryTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @namespace = "test-#{SecureRandom.hex}"
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
end
