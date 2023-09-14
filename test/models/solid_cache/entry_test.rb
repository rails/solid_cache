require "test_helper"

module SolidCache
  class EntryTest < ActiveSupport::TestCase
    test "set and get cache entries" do
      Entry.set("hello".b, "there")
      assert_equal "there", Entry.get("hello".b)
    end

    test "set all and get all cache entries" do
      Entry.set_all([ { key: "hello".b, value: "there" }, { key: "foo".b, value: "bar" } ])
      assert_equal({ "foo" => "bar", "hello" => "there" } , Entry.get_all(["hello".b, "foo".b, "bar".b]))
    end

    test "id range" do
      assert_equal 0, Entry.id_range

      Entry.set("hello".b, "there")
      Entry.set("hello2".b, "there")

      assert_equal 2, Entry.id_range
    end
  end
end
