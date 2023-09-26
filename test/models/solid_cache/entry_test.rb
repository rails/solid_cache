require "test_helper"

module SolidCache
  class EntryTest < ActiveSupport::TestCase
    test "write and read cache entries" do
      Entry.write("hello".b, "there")
      assert_equal "there", Entry.read("hello".b)
    end

    test "write multi and read multi cache entries" do
      Entry.write_multi([ { key: "hello".b, value: "there" }, { key: "foo".b, value: "bar" } ])
      assert_equal({ "foo" => "bar", "hello" => "there" }, Entry.read_multi([ "hello".b, "foo".b, "bar".b ]))
    end

    test "id range" do
      assert_equal 0, Entry.id_range

      Entry.write("hello".b, "there")
      Entry.write("hello2".b, "there")

      assert_equal 2, Entry.uncached { Entry.id_range }
    end

    test "clear with truncate" do
      write_entries
      assert_equal 20, uncached_entry_count
      Entry.clear_truncate
      assert_equal 0, uncached_entry_count
    end

    test "clear with delete" do
      write_entries
      assert_equal 20, uncached_entry_count
      Entry.clear_delete
      assert_equal 0, uncached_entry_count
    end

    private
      def write_entries(count = 20)
        Entry.write_multi(count.times.map { |i| { key: "key#{i}", value: "value#{i}" } })
      end
  end
end
