# frozen_string_literal: true

require "test_helper"
require "active_support/testing/method_call_assertions"

class SolidCache::ExpiryTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers
  include ActiveJob::TestHelper

  setup do
    @namespace = "test-#{SecureRandom.hex}"
    @single_shard_cluster = single_database? ? {} : { shards: [ first_shard_key ] }
    skip if multi_cluster?
  end

  teardown do
    wait_for_background_tasks(@cache) if @cache
  end

  [ :thread, :job ].each do |expiry_method|
    test "expires old records (#{expiry_method})" do
      SolidCache::Cluster.any_instance.stubs(:rand).returns(0)

      @cache = lookup_store(expiry_batch_size: 3, max_age: 2.weeks, expiry_method: expiry_method)
      default_shard_keys = shard_keys(@cache, first_shard_key)
      @cache.write(default_shard_keys[0], 1)
      @cache.write(default_shard_keys[1], 2)
      assert_equal 1, @cache.read(default_shard_keys[0])
      assert_equal 2, @cache.read(default_shard_keys[1])

      send_entries_back_in_time(3.weeks)

      @cache.write(default_shard_keys[2], 3)
      @cache.write(default_shard_keys[3], 4)

      wait_for_background_tasks(@cache)
      perform_enqueued_jobs

      assert_nil @cache.read(default_shard_keys[0])
      assert_nil @cache.read(default_shard_keys[1])
      assert_equal 3, @cache.read(default_shard_keys[2])
      assert_equal 4, @cache.read(default_shard_keys[3])
    end

    test "expires records when the cache is full (#{expiry_method})" do
      SolidCache::Cluster.any_instance.stubs(:rand).returns(0)

      @cache = lookup_store(expiry_batch_size: 3, max_age: nil, max_entries: 2, expiry_method: expiry_method)
      default_shard_keys = shard_keys(@cache, first_shard_key)
      @cache.write(default_shard_keys[0], 1)
      @cache.write(default_shard_keys[1], 2)

      wait_for_background_tasks(@cache)

      @cache.write(default_shard_keys[2], 3)
      @cache.write(default_shard_keys[3], 4)

      wait_for_background_tasks(@cache)
      perform_enqueued_jobs

      # Two records have been deleted
      assert_equal 1, SolidCache::Record.each_shard.sum { SolidCache::Entry.count }
    end

    test "expires records when the cache is full via max_size (#{expiry_method})" do
      SolidCache::Cluster.any_instance.stubs(:rand).returns(0)

      @cache = lookup_store(expiry_batch_size: 3, max_age: nil, max_size: 1000, expiry_method: expiry_method)
      default_shard_keys = shard_keys(@cache, first_shard_key)
      @cache.write(default_shard_keys[0], "a" * 350)
      @cache.write(default_shard_keys[1], "a" * 350)

      sleep 0.1

      @cache.write(default_shard_keys[2], "a" * 350)
      @cache.write(default_shard_keys[3], "a" * 350)

      sleep 0.1
      perform_enqueued_jobs

      # Two records have been deleted
      assert_equal 1, SolidCache::Record.each_shard.sum { SolidCache::Entry.count }
    end

    test "expires records no shards (#{expiry_method})" do
      SolidCache::Cluster.any_instance.stubs(:rand).returns(0)

      @cache = ActiveSupport::Cache.lookup_store(:solid_cache_store, expiry_batch_size: 3, namespace: @namespace, max_entries: 2, expiry_method: expiry_method, clusters: [ @single_shard_cluster ])
      default_shard_keys = shard_keys(@cache, first_shard_key)

      @cache.write(default_shard_keys[0], 1)
      @cache.write(default_shard_keys[1], 2)

      wait_for_background_tasks(@cache)

      @cache.write(default_shard_keys[2], 3)
      @cache.write(default_shard_keys[3], 4)

      wait_for_background_tasks(@cache)
      perform_enqueued_jobs

      # Three records have been deleted
      assert_equal 1, SolidCache::Record.each_shard.sum { SolidCache::Entry.count }
    end

    test "expires when random number is below threshold (#{expiry_method})" do
      SolidCache::Cluster.any_instance.stubs(:rand).returns(0.416)

      @cache = ActiveSupport::Cache.lookup_store(:solid_cache_store, expiry_batch_size: 3, namespace: @namespace, max_entries: 1, expiry_method: expiry_method)
      default_shard_keys = shard_keys(@cache, first_shard_key)

      @cache.write(default_shard_keys[0], 1)
      @cache.write(default_shard_keys[1], 2)

      wait_for_background_tasks(@cache)
      perform_enqueued_jobs

      assert_equal 0, SolidCache::Record.each_shard.sum { SolidCache::Entry.count }
    end

    test "doesn't expire when random number is above threshold (#{expiry_method})" do
      SolidCache::Cluster.any_instance.stubs(:rand).returns(0.417)

      @cache = ActiveSupport::Cache.lookup_store(:solid_cache_store, expiry_batch_size: 6, namespace: @namespace, max_entries: 1, expiry_method: expiry_method)
      default_shard_keys = shard_keys(@cache, first_shard_key)

      @cache.write(default_shard_keys[0], 1)
      @cache.write(default_shard_keys[1], 2)

      wait_for_background_tasks(@cache)
      perform_enqueued_jobs

      assert_equal 2, SolidCache::Record.each_shard.sum { SolidCache::Entry.count }
    end

    test "expires old records multiple shards (#{expiry_method})" do
      skip if single_database?

      SolidCache::Cluster.any_instance.stubs(:rand).returns(0, 1, 0, 1, 0, 1, 0, 1)
      @cache = lookup_store(expiry_batch_size: 2, clusters: [ { shards: [ first_shard_key, second_shard_key ] } ], expiry_method: expiry_method)
      default_shard_keys = shard_keys(@cache, first_shard_key)
      shard_one_keys = shard_keys(@cache, second_shard_key)

      @cache.write(default_shard_keys[0], 1)
      @cache.write(default_shard_keys[1], 2)
      @cache.write(shard_one_keys[0], 3)
      @cache.write(shard_one_keys[1], 4)

      assert_equal 1, @cache.read(default_shard_keys[0])
      assert_equal 2, @cache.read(default_shard_keys[1])
      assert_equal 3, @cache.read(shard_one_keys[0])
      assert_equal 4, @cache.read(shard_one_keys[1])

      wait_for_background_tasks(@cache)
      send_entries_back_in_time(3.weeks)

      @cache.write(default_shard_keys[2], 5)
      @cache.write(default_shard_keys[3], 6)
      @cache.write(shard_one_keys[2], 7)
      @cache.write(shard_one_keys[3], 8)

      wait_for_background_tasks(@cache)
      perform_enqueued_jobs

      assert_nil @cache.read(default_shard_keys[0])
      assert_nil @cache.read(default_shard_keys[1])
      assert_nil @cache.read(shard_one_keys[0])
      assert_nil @cache.read(shard_one_keys[1])
      assert_equal 5, @cache.read(default_shard_keys[2])
      assert_equal 6, @cache.read(default_shard_keys[3])
      assert_equal 7, @cache.read(shard_one_keys[2])
      assert_equal 8, @cache.read(shard_one_keys[3])

      [ first_shard_key, :primary_shard_one ].each do |shard|
        SolidCache::Record.connected_to(shard: shard) do
          assert_equal 2, SolidCache::Entry.count
        end
      end
    end
  end

  test "expires old records with a custom queue" do
    SolidCache::Cluster.any_instance.stubs(:rand).returns(0, 1, 0, 1)

    @cache = lookup_store(expiry_batch_size: 3, max_entries: 2, expiry_method: :job, expiry_queue: :cache_expiry)

    default_shard_keys = shard_keys(@cache, first_shard_key)

    assert_enqueued_jobs(2, only: SolidCache::ExpiryJob, queue: :cache_expiry) do
      @cache.write(default_shard_keys[0], 1)
      @cache.write(default_shard_keys[1], 2)
      @cache.write(default_shard_keys[2], 3)
      @cache.write(default_shard_keys[2], 4)
    end

    perform_enqueued_jobs
    assert_equal 0, SolidCache::Record.each_shard.sum { SolidCache::Entry.count }
  end

  test "triggers multiple expiry tasks when there are many writes" do
    @cache = lookup_store(expiry_batch_size: 20, max_entries: 2, expiry_queue: :cache_expiry, clusters: [ @single_shard_cluster ])
    background = @cache.primary_cluster.instance_variable_get("@background")

    SolidCache::Cluster.any_instance.stubs(:rand).returns(0.25, 0.24)
    # We expect 2 expiry job for 8 writes
    assert_difference -> { background.scheduled_task_count }, +1 do
      @cache.write_multi(8.times.index_by { |i| "key#{i}" })
      wait_for_background_tasks(@cache)
    end

    assert_difference -> { background.scheduled_task_count }, +3 do
      @cache.write_multi(24.times.index_by { |i| "key#{i}" })
      wait_for_background_tasks(@cache)
    end

    # Whether we overflow an extra job depends on rand
    SolidCache::Cluster.any_instance.stubs(:rand).returns(0.25, 0.24)
    assert_difference -> { background.scheduled_task_count }, +1 do
      @cache.write_multi(10.times.index_by { |i| "key#{i}" })
      wait_for_background_tasks(@cache)
    end

    assert_difference -> { background.scheduled_task_count }, +1 do
      @cache.write_multi(10.times.index_by { |i| "key#{i}" })
      wait_for_background_tasks(@cache)
    end
  end

  test "triggers multiple expiry jobs when there are many writes" do
    @cache = lookup_store(expiry_batch_size: 10, max_entries: 4, expiry_queue: :cache_expiry, expiry_method: :job, clusters: [ @single_shard_cluster ])

    SolidCache::Cluster.any_instance.stubs(:rand).returns(0.25, 0.24)
    # We expect 1 expiry job for 8 writes
    assert_enqueued_jobs(2, only: SolidCache::ExpiryJob) do
      @cache.write_multi(8.times.index_by { |i| "key#{i}" })
    end

    assert_enqueued_jobs(5, only: SolidCache::ExpiryJob) do
      @cache.write_multi(24.times.index_by { |i| "key#{i}" })
    end

    # Whether we overflow an extra job depends on rand
    SolidCache::Cluster.any_instance.stubs(:rand).returns(0.125, 0.124)
    assert_enqueued_jobs(2, only: SolidCache::ExpiryJob) do
      @cache.write_multi(10.times.index_by { |i| "key#{i}" })
    end

    assert_enqueued_jobs(2, only: SolidCache::ExpiryJob) do
      @cache.write_multi(10.times.index_by { |i| "key#{i}" })
    end
  end

  private
    def shard_keys(cache, shard)
      namespaced_keys = 100.times.map { |i| @cache.send(:normalize_key, "key#{i}", {}) }
      shard_keys = cache.primary_cluster.send(:connections).assign(namespaced_keys)[shard]
      shard_keys.map { |key| key.delete_prefix("#{@namespace}:") }
    end
end
