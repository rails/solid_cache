require "test_helper"
require "active_support/testing/method_call_assertions"

class SolidCache::StatsTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @namespace = "test-#{SecureRandom.hex}"
  end

  def test_stats_one_shard
    @cache = lookup_store(trim_batch_size: 2, max_age: 2.weeks.to_i, max_entries: 1000, cluster: { shards: [ :default ] })

    expected = {
      shards: 1,
      shards_stats: {
        default: { max_age: 2.weeks.to_i, oldest_age: nil, max_entries: 1000, entries: 0 }
      }
    }

    assert_equal expected, @cache.stats
  end

  unless ENV["NO_CONNECTS_TO"]
    def test_stats_multiple_shards
      @cache = lookup_store(trim_batch_size: 2, max_age: 2.weeks.to_i, max_entries: 1000, cluster: { shards: [:default, :default2] })

      expected = {
        shards: 2,
        shards_stats: {
          default: { max_age: 2.weeks.to_i, oldest_age: nil, max_entries: 1000, entries: 0 },
          default2: { max_age: 2.weeks.to_i, oldest_age: nil, max_entries: 1000, entries: 0 }
        }
      }

      assert_equal expected, @cache.stats
    end
  end

  def test_stats_with_entries
    @cache = lookup_store(trim_batch_size: 2, max_age: 2.weeks.to_i, max_entries: 1000, cluster: { shards: [:default] })

    expected_empty = { shards: 1, shards_stats: { default: { max_age: 2.weeks.to_i, oldest_age: nil, max_entries: 1000, entries: 0 } } }

    assert_equal expected_empty, @cache.stats

    freeze_time
    @cache.write("foo", 1)
    @cache.write("bar", 1)

    SolidCache::Entry.update_all(created_at: Time.now - 20.minutes)

    expected_not_empty = { shards: 1, shards_stats: { default: { max_age: 2.weeks.to_i, oldest_age: 20.minutes.to_i, max_entries: 1000, entries: 2 } } }

    assert_equal expected_not_empty, @cache.stats
  end
end
