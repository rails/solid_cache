require "test_helper"
require "active_support/testing/method_call_assertions"

class ActiveSupport::DatabaseCache::HousekeeperTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @cache = nil
    @namespace = "test-#{SecureRandom.hex}"

    @cache = lookup_store(housekeeper: true, housekeeper_options: { delete_by: :updated_at, delete_age: 2.weeks, touch_batch_size: 2, delete_batch_size: 2 })
  end

  teardown do
    @cache.housekeeper.stop
  end

  def test_deletes_old_records
    @cache.write("foo", 1)
    @cache.write("bar", 2)
    assert_equal 1, @cache.read("foo")
    assert_equal 2, @cache.read("bar")
    sleep 0.1 # ensure the housekeeper has marked them as read

    send_entries_back_in_time(3.weeks)

    @cache.write("baz", 3)
    @cache.write("haz", 4)

    sleep 0.1
    assert_nil @cache.read("foo")
    assert_nil @cache.read("bar")
    assert_equal 3, @cache.read("baz")
    assert_equal 4, @cache.read("haz")
  end

  def test_touches_records
    @cache.write("foo", 1)
    @cache.write("bar", 2)
    assert_equal 1, @cache.read("foo")
    assert_equal 2, @cache.read("bar")
    sleep 0.1 # ensure the housekeeper has marked them as read

    send_entries_back_in_time(1.week)

    assert_equal 1, @cache.read("foo")
    assert_equal 2, @cache.read("bar")
    sleep 0.1

    assert_equal 2, ActiveSupport::DatabaseCache::Entry.where("updated_at > ?", Time.now - 1.minute).count
  end

  private
    def send_entries_back_in_time(distance)
      ActiveSupport::DatabaseCache::Entry.all.each do |entry|
        entry.update_columns(created_at: entry.created_at - distance, updated_at: entry.updated_at - distance)
      end
    end
end
