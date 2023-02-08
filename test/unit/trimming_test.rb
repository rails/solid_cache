require "test_helper"
require "active_support/testing/method_call_assertions"

class SolidCache::TrimmingTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @namespace = "test-#{SecureRandom.hex}"
  end

  def test_trims_old_records
    @cache = lookup_store(touch_batch_size: 2, trim_batch_size: 2, shards: [:default])
    @cache.write("foo", 1)
    @cache.write("bar", 2)
    assert_equal 1, @cache.read("foo")
    assert_equal 2, @cache.read("bar")
    sleep 0.1 # ensure they are marked as read

    send_entries_back_in_time(3.weeks)

    @cache.write("baz", 3)
    @cache.write("haz", 4)

    sleep 0.1
    assert_nil @cache.read("foo")
    assert_nil @cache.read("bar")
    assert_equal 3, @cache.read("baz")
    assert_equal 4, @cache.read("haz")
  end

  def test_trims_newer_records_when_the_cache_is_full
    cache_full_value = false
    cache_full = ->() { cache_full_value }
    @cache = lookup_store(touch_batch_size: 2, trim_batch_size: 2, shards: [:default], max_age: 2.weeks, cache_full: cache_full)
    @cache.write("foo", 1)
    @cache.write("bar", 2)
    assert_equal 1, @cache.read("foo")
    assert_equal 2, @cache.read("bar")
    sleep 0.1 # ensure they are marked as read

    cache_full_value = true

    @cache.write("baz", 3)
    @cache.write("haz", 4)

    sleep 0.1

    # Two records have been deleted
    assert_equal 2, SolidCache::Entry.count
  end

  def test_trims_old_records_multiple_shards
    @cache = lookup_store(touch_batch_size: 2, trim_batch_size: 2)
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

  def test_trims_by_expiry
    @cache = lookup_store(touch_batch_size: 2, trim_batch_size: 2, shards: [:default], trim_by: :expiry)
    @cache.write("foo", 1, expires_at: Time.now + 1.minute)
    @cache.write("bar", 2, expires_at: Time.now + 2.minutes)
    @cache.write("baz", 3, expires_at: Time.now + 60.minutes)
    @cache.write("zab", 4, expires_at: nil)
    assert_equal 1, @cache.read("foo")
    assert_equal 2, @cache.read("bar")
    sleep 0.1 # ensure they are marked as read

    @cache.read("foo")
    @cache.read("bar")

    travel_to Time.now + 5.minutes
    @cache.write("daz", 5)
    @cache.write("haz", 6)

    sleep 0.1
    assert_nil @cache.read("foo")
    assert_nil @cache.read("bar")
    assert_equal 3, @cache.read("baz")
    assert_equal 4, @cache.read("zab")

    assert_equal 4, SolidCache::Entry.count
    assert_equal namespaced_keys(%w{ baz daz haz zab }), SolidCache::Entry.pluck(:key).sort
  end

  def test_trims_by_expiry_with_lru_shortfall
    cache_full_value = false
    cache_full = ->() { cache_full_value }
    @cache = lookup_store(touch_batch_size: 2, trim_batch_size: 2, shards: [:default], max_age: 2.weeks, cache_full: cache_full, trim_by: :expiry)

    @cache.write("foo", 1, expires_at: Time.now + 1.minute)
    @cache.write("bar", 2, expires_at: nil)
    @cache.write("baz", 3, expires_at: nil)
    @cache.write("zab", 4, expires_at: nil)
    sleep 0.1

    travel_to Time.now + 5.minutes
    cache_full_value = true
    @cache.write("daz", 5)
    @cache.write("haz", 6)
    @cache.write("maz", 7)

    sleep 0.1

    # 4 records have been deleted
    assert_equal 3, SolidCache::Entry.count
    # 1 of them is the expired record
    assert_not SolidCache::Entry.where(key: namespaced_key("foo")).exists?
  end

  private
    def namespaced_keys(keys)
      keys.map { |key| namespaced_key(key) }
    end

    def namespaced_key(key)
      "#{@namespace}:#{key}"
    end
end
