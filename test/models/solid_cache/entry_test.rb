require "test_helper"

module SolidCache
  class EntryTest < ActiveSupport::TestCase
    test "set and get cache entries" do
      Entry.set("hello".b, "there")
      assert_equal "there", Entry.get("hello".b)[1]
    end
  end
end
