require "test_helper"
require "active_support/testing/method_call_assertions"

class SolidCache::TrimmingTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @namespace = "test-#{SecureRandom.hex}"
  end

  def test_trims_old_records
    @cache = lookup_store(trim_batch_size: 2, max_age: 2.weeks, shards: [:default])
    @cache.write("foo", 1)
    @cache.write("bar", 2)
    assert_equal 1, @cache.read("foo")
    assert_equal 2, @cache.read("bar")

    send_entries_back_in_time(3.weeks)

    @cache.write("baz", 3)
    @cache.write("haz", 4)

    sleep 0.1
    assert_nil @cache.read("foo")
    assert_nil @cache.read("bar")
    assert_equal 3, @cache.read("baz")
    assert_equal 4, @cache.read("haz")
  end

  def test_trims_records_when_the_cache_is_full
    @cache = lookup_store(trim_batch_size: 2, shards: [:default], max_age: 2.weeks, max_entries: 2)
    @cache.write("foo", 1)
    @cache.write("bar", 2)

    sleep 0.1

    @cache.write("baz", 3)
    @cache.write("haz", 4)

    sleep 0.1

    # Two records have been deleted
    assert_equal 2, SolidCache::Entry.count
  end

  def test_trims_old_records_multiple_shards
    @cache = lookup_store(trim_batch_size: 2)
    default_shard_keys, shard_one_keys = 20.times.map { |i| "key#{i}" }.partition { |key| @cache.shard_for_key(key) == :default }

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

    assert_nil @cache.read(default_shard_keys[0])
    assert_nil @cache.read(default_shard_keys[1])
    assert_nil @cache.read(shard_one_keys[0])
    assert_nil @cache.read(shard_one_keys[1])
    assert_equal 5, @cache.read(default_shard_keys[2])
    assert_equal 6, @cache.read(default_shard_keys[3])
    assert_equal 7, @cache.read(shard_one_keys[2])
    assert_equal 8, @cache.read(shard_one_keys[3])

    [:default, :shard_one].each do |shard|
      SolidCache::Record.connected_to(shard: shard) do
        assert_equal 2, SolidCache::Entry.count
      end
    end
  end

  private
    def namespaced_keys(keys)
      keys.map { |key| namespaced_key(key) }
    end

    def namespaced_key(key)
      "#{@namespace}:#{key}"
    end
end
