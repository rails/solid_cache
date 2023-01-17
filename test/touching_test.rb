require "test_helper"
require "active_support/testing/method_call_assertions"

class SolidCache::TrimmingTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @namespace = "test-#{SecureRandom.hex}"
  end

  def test_touches_read_records_single_shard
    @cache = lookup_store(touch_batch_size: 2, trim_batch_size: 2, shards: nil)
    @cache.write("foo", 1)
    @cache.write("bar", 2)
    assert_equal 1, @cache.read("foo")
    assert_equal 2, @cache.read("bar")

    sleep 0.1 # wait for them to be marked as read

    send_entries_back_in_time(1.week)

    assert_equal 1, @cache.read("foo")
    assert_equal 2, @cache.read("bar")

    sleep 0.1

    assert_equal 2, SolidCache::Entry.where("updated_at > ?", Time.now - 1.minute).count
  end

  def test_touches_read_records_multiple_shards
    @cache = lookup_store(touch_batch_size: 2, trim_batch_size: 2, shards: [:default, :shard_one])
    default_shard_keys, shard_one_keys = 20.times.map { |i| "key#{i}" }.partition { |key| @cache.shard_for_key(key) == :default }

    @cache.write(default_shard_keys[0], 1)
    @cache.write(default_shard_keys[1], 2)
    @cache.write(shard_one_keys[0], 3)
    @cache.write(shard_one_keys[1], 4)

    assert_equal 1, @cache.read(default_shard_keys[0])
    assert_equal 2, @cache.read(default_shard_keys[1])
    assert_equal 3, @cache.read(shard_one_keys[0])
    assert_equal 4, @cache.read(shard_one_keys[1])

    sleep 0.1 # wait for them to be marked as read

    send_entries_back_in_time(1.week)

    assert_equal 1, @cache.read(default_shard_keys[0])
    assert_equal 2, @cache.read(default_shard_keys[1])
    assert_equal 3, @cache.read(shard_one_keys[0])
    assert_equal 4, @cache.read(shard_one_keys[1])

    sleep 0.1

    [:default, :shard_one].each do |shard|
      SolidCache::Record.connected_to(shard: shard) do
        assert_equal 2, SolidCache::Entry.where("updated_at > ?", Time.now - 1.minute).count
      end
    end
  end
end
