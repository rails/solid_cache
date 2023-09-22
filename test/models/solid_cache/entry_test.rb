require "test_helper"

module SolidCache
  class EntryTest < ActiveSupport::TestCase
    test "write and read cache entries" do
      Entry.write("hello".b, "there")
      assert_equal "there", Entry.read("hello".b)
    end

    test "write multi and read multi cache entries" do
      Entry.write_multi([ { key: "hello".b, value: "there" }, { key: "foo".b, value: "bar" } ])
      assert_equal({ "foo" => "bar", "hello" => "there" } , Entry.read_multi(["hello".b, "foo".b, "bar".b]))
    end

    test "id range" do
      assert_equal 0, Entry.id_range

      Entry.write("hello".b, "there")
      Entry.write("hello2".b, "there")

      assert_equal 2, Entry.uncached { Entry.id_range }
    end
  end
end
