require "test_helper"
require "active_support/testing/method_call_assertions"

class SolidCache::ExpiryTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers
  include ActiveJob::TestHelper

  setup do
    @namespace = "test-#{SecureRandom.hex}"
    SolidCache::Cluster.any_instance.stubs(:rand).returns(0)
  end

  [ :thread, :job ].each do |expiry_method|
    test "expires old records (#{expiry_method})" do
      @cache = lookup_store(expiry_batch_size: 3, max_age: 2.weeks, expiry_method: expiry_method)
      default_shard_keys = shard_keys(@cache, :default)
      @cache.write(default_shard_keys[0], 1)
      @cache.write(default_shard_keys[1], 2)
      assert_equal 1, @cache.read(default_shard_keys[0])
      assert_equal 2, @cache.read(default_shard_keys[1])

      send_entries_back_in_time(3.weeks)

      @cache.write(default_shard_keys[2], 3)
      @cache.write(default_shard_keys[3], 4)

      sleep 0.1
      perform_enqueued_jobs

      assert_nil @cache.read(default_shard_keys[0])
      assert_nil @cache.read(default_shard_keys[1])
      assert_equal 3, @cache.read(default_shard_keys[2])
      assert_equal 4, @cache.read(default_shard_keys[3])
    end

    test "expires records when the cache is full (#{expiry_method})" do
      @cache = lookup_store(expiry_batch_size: 3, max_age: 2.weeks, max_entries: 2, expiry_method: expiry_method)
      default_shard_keys = shard_keys(@cache, :default)
      @cache.write(default_shard_keys[0], 1)
      @cache.write(default_shard_keys[1], 2)

      sleep 0.1

      @cache.write(default_shard_keys[2], 3)
      @cache.write(default_shard_keys[3], 4)

      sleep 0.1
      perform_enqueued_jobs

      # Two records have been deleted
      assert_equal 1, SolidCache.each_shard.sum { SolidCache::Entry.count }
    end

    test "expires records no shards (#{expiry_method})" do
      @cache = ActiveSupport::Cache.lookup_store(:solid_cache_store, expiry_batch_size: 3, namespace: @namespace, max_entries: 2, expiry_method: expiry_method)
      default_shard_keys = shard_keys(@cache, :default)

      @cache.write(default_shard_keys[0], 1)
      @cache.write(default_shard_keys[1], 2)

      sleep 0.1

      @cache.write(default_shard_keys[2], 3)
      @cache.write(default_shard_keys[3], 4)

      sleep 0.1
      perform_enqueued_jobs

      # Three records have been deleted
      assert_equal 1, SolidCache.each_shard.sum { SolidCache::Entry.count }
    end

    unless ENV["NO_CONNECTS_TO"]
      test "expires old records multiple shards (#{expiry_method})" do
        @cache = lookup_store(expiry_batch_size: 2, cluster: { shards: [ :default, :primary_shard_one ] }, expiry_method: expiry_method)
        default_shard_keys = shard_keys(@cache, :default)
        shard_one_keys = shard_keys(@cache, :primary_shard_one)

        @cache.write(default_shard_keys[0], 1)
        @cache.write(default_shard_keys[1], 2)
        @cache.write(shard_one_keys[0], 3)
        @cache.write(shard_one_keys[1], 4)

        assert_equal 1, @cache.read(default_shard_keys[0])
        assert_equal 2, @cache.read(default_shard_keys[1])
        assert_equal 3, @cache.read(shard_one_keys[0])
        assert_equal 4, @cache.read(shard_one_keys[1])

        sleep 0.1 # ensure they are marked as read
        send_entries_back_in_time(3.weeks)

        @cache.write(default_shard_keys[2], 5)
        @cache.write(default_shard_keys[3], 6)
        @cache.write(shard_one_keys[2], 7)
        @cache.write(shard_one_keys[3], 8)

        sleep 0.1
        perform_enqueued_jobs

        assert_nil @cache.read(default_shard_keys[0])
        assert_nil @cache.read(default_shard_keys[1])
        assert_nil @cache.read(shard_one_keys[0])
        assert_nil @cache.read(shard_one_keys[1])
        assert_equal 5, @cache.read(default_shard_keys[2])
        assert_equal 6, @cache.read(default_shard_keys[3])
        assert_equal 7, @cache.read(shard_one_keys[2])
        assert_equal 8, @cache.read(shard_one_keys[3])

        [ :default, :primary_shard_one ].each do |shard|
          SolidCache::Record.connected_to(shard: shard) do
            assert_equal 2, SolidCache::Entry.count
          end
        end
      end
    end
  end

    private
      def shard_keys(cache, shard)
        namespaced_keys = 100.times.map { |i| @cache.send(:normalize_key, "key#{i}", {}) }
        shard_keys = cache.primary_cluster.send(:connections).assign(namespaced_keys)[shard]
        shard_keys.map { |key| key.delete_prefix("#{@namespace}:") }
      end
end
