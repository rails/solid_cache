require "test_helper"
require "active_support/testing/method_call_assertions"

class SolidCache::StatsTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @namespace = "test-#{SecureRandom.hex}"
  end

  if ENV["NO_CONNECTS_TO"]
    def test_stats_with_entries_no_shards
      @cache = lookup_store(trim_batch_size: 2, max_age: 2.weeks.to_i, max_entries: 1000)

      expected_empty = { connections: 1, connection_stats: { default: { max_age: 2.weeks.to_i, oldest_age: nil, max_entries: 1000, entries: 0 } } }

      assert_equal expected_empty, @cache.stats

      freeze_time
      @cache.write("foo", 1)
      @cache.write("bar", 1)

      SolidCache.each_shard do
        SolidCache::Entry.update_all(created_at: Time.now - 20.minutes)
      end

      expected_not_empty = { connections: 1, connection_stats: { default: { max_age: 2.weeks.to_i, oldest_age: 20.minutes.to_i, max_entries: 1000, entries: 2 } } }
      assert_equal expected_not_empty, @cache.stats
    end
  else
    def test_stats_with_entries_no_shards
      @cache = lookup_store(trim_batch_size: 2, max_age: 2.weeks.to_i, max_entries: 1000)

      expected_empty = { connections: 5, connection_stats: {
        default: { max_age: 2.weeks.to_i, oldest_age: nil, max_entries: 1000, entries: 0 },
        primary_shard_one: { max_age: 2.weeks.to_i, oldest_age: nil, max_entries: 1000, entries: 0 },
        primary_shard_two: { max_age: 2.weeks.to_i, oldest_age: nil, max_entries: 1000, entries: 0 },
        secondary_shard_one: { max_age: 2.weeks.to_i, oldest_age: nil, max_entries: 1000, entries: 0 },
        secondary_shard_two: { max_age: 2.weeks.to_i, oldest_age: nil, max_entries: 1000, entries: 0 }
      } }

      assert_equal expected_empty, @cache.stats

      freeze_time
      @cache.write("foo", 1)
      @cache.write("bar", 1)

      SolidCache.each_shard do
        SolidCache::Entry.update_all(created_at: Time.now - 20.minutes)
      end

      stats = @cache.stats

      assert_equal 20.minutes.to_i, stats[:connection_stats].values.map { |value| value[:oldest_age] }.compact.min
      assert_equal 2, stats[:connection_stats].values.map { |value| value[:entries] }.compact.sum
    end

    def test_stats_one_shard
      @cache = lookup_store(trim_batch_size: 2, max_age: 2.weeks.to_i, max_entries: 1000, cluster: { shards: [:default] })

      expected = {
        connections: 1,
        connection_stats: {
          default: { max_age: 2.weeks.to_i, oldest_age: nil, max_entries: 1000, entries: 0 }
        }
      }

      assert_equal expected, @cache.stats
    end

    def test_stats_multiple_shards
      @cache = lookup_store(trim_batch_size: 2, max_age: 2.weeks.to_i, max_entries: 1000, cluster: { shards: [:default, :primary_shard_one] })

      expected = {
        connections: 2,
        connection_stats: {
          default: { max_age: 2.weeks.to_i, oldest_age: nil, max_entries: 1000, entries: 0 },
          primary_shard_one: { max_age: 2.weeks.to_i, oldest_age: nil, max_entries: 1000, entries: 0 }
        }
      }

      assert_equal expected, @cache.stats
    end
  end
end
