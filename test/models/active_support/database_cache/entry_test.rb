require "test_helper"

module ActiveSupport::DatabaseCache
  class EntryTest < ActiveSupport::TestCase
    test "set and get cache entries" do
      Entry.set("hello".b, "there")
      assert_equal "there", Entry.get("hello".b)
    end
  end
end
