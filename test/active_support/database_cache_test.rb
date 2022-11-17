require "test_helper"

class ActiveSupport::DatabaseCacheTest < ActiveSupport::TestCase
  setup do
    @cache = ActiveSupport::Cache::DatabaseCacheStore.new
  end

  test "can read a record" do
    @cache.write("foo", "bar")
    assert_equal "bar", @cache.read("foo")
  end

  test "can delete a record" do
    @cache.write("foo", "bar")
    @cache.delete("foo")
    assert_nil @cache.read("foo")
  end

  test "expires records" do
    @cache.write("foo", "bar", expires_at: Time.now + 0.01)
    assert_equal "bar", @cache.read("foo")
    sleep(0.015)
    assert_nil @cache.read("foo")
  end

  test "writes multiple records" do
    @cache.write_multi( "foo" => "bar", "boo" => "far", "roo" => "barb" )
    assert_equal "bar", @cache.read("foo")
    assert_equal "far", @cache.read("boo")
    assert_equal "barb", @cache.read("roo")
  end

  test "reads multiple records" do
    @cache.write("foo", "bar")
    @cache.write("boo", "far")
    @cache.write("roo", "barb")
    assert_equal({ "foo" => "bar", "roo" => "barb" }, @cache.read_multi("foo", "roo"))
  end
end
