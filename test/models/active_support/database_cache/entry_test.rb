require "test_helper"

module ActiveSupport::DatabaseCache
  class EntryTest < ActiveSupport::TestCase
    test "set and get cache entries" do
      Entry.set("hello", "there")
      assert_equal "there", Entry.get("hello")
    end

    test "returns unexpired entries" do
      Entry.set("hello", "there", expires_at: Time.now + 2.days)
      assert_equal "there", Entry.get("hello")
    end

    test "expires entries" do
      Entry.set("hello", "there", expires_at: Time.now + 0.01)
      sleep 0.015
      assert_nil Entry.get("hello")
    end
  end
end
