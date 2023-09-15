require "test_helper"

class QueryCacheTest < ActiveSupport::TestCase
  setup do
    @cache = nil
    @namespace = "test-#{SecureRandom.hex}"

    @cache = lookup_store(expires_in: 60, cluster: { shards: [:default] })
    @peek = lookup_store(expires_in: 60, cluster: { shards: [:default] })
  end

  test "writes don't clear the AR cache" do
    SolidCache::Entry.cache do
      @cache.write(1, "foo")
      assert_equal 1, SolidCache::Entry.count
      @cache.write(2, "bar")
      assert_equal 1, SolidCache::Entry.count
    end
    SolidCache::Entry.uncached do
      assert_equal 2, SolidCache::Entry.count
    end
  end

  test "write_multi doesn't clear the AR cache" do
    SolidCache::Entry.cache do
      @cache.write(1, "foo")
      assert_equal 1, SolidCache::Entry.count
      @cache.write_multi({ "1" => "bar", "2" => "baz"})
      assert_equal 1, SolidCache::Entry.count
    end
    SolidCache::Entry.uncached do
      assert_equal 2, SolidCache::Entry.count
    end
  end

  test "deletes don't clear the AR cache" do
    SolidCache::Entry.cache do
      @cache.write(1, "foo")
      assert_equal 1, SolidCache::Entry.count
      @cache.delete(1)
      assert_equal 1, SolidCache::Entry.count
    end
    SolidCache::Entry.uncached do
      assert_equal 0, SolidCache::Entry.count
    end
  end

  test "delete matches don't clear the AR cache" do
    SolidCache::Entry.cache do
      @cache.write("hello1", "foo")
      @cache.write("hello2", "bar")
      assert_equal 2, SolidCache::Entry.count
      @cache.delete_matched("hello%")
      assert_equal 2, SolidCache::Entry.count
    end
    SolidCache::Entry.uncached do
      assert_equal 0, SolidCache::Entry.count
    end
  end
end
