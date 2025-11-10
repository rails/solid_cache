# frozen_string_literal: true

require "test_helper"

class SolidCache::ConfigurationTest < ActiveSupport::TestCase
  test "databases option accepts a single database name as a string" do
    config = SolidCache::Configuration.new(databases: "cache")
    assert_equal({ shards: { cache: { writing: :cache } } }, config.connects_to)
  end

  test "databases option accepts a single database name as a symbol" do
    config = SolidCache::Configuration.new(databases: :cache)
    assert_equal({ shards: { cache: { writing: :cache } } }, config.connects_to)
  end

  test "databases option accepts an array of database names" do
    config = SolidCache::Configuration.new(databases: [:cache1, :cache2])
    assert_equal({
      shards: {
        cache1: { writing: :cache1 },
        cache2: { writing: :cache2 }
      }
    }, config.connects_to)
  end

  test "database option accepts a single database name" do
    config = SolidCache::Configuration.new(database: :cache)
    assert_equal({ shards: { cache: { writing: :cache } } }, config.connects_to)
  end

  test "database option also accepts an array of database names" do
    config = SolidCache::Configuration.new(database: [:cache1, :cache2])
    assert_equal({
      shards: {
        cache1: { writing: :cache1 },
        cache2: { writing: :cache2 }
      }
    }, config.connects_to)
  end

  test "should respect connects_to option" do
    connects_to = {
      shards: {
        cache1: { writing: :cache1 },
        cache2: { writing: :cache2 }
      }
    }
    config = SolidCache::Configuration.new(connects_to: connects_to)
    assert_equal(connects_to, config.connects_to)
  end

  test "raises ArgumentError when multiple connection options are provided" do
    error = assert_raises(ArgumentError) do
      SolidCache::Configuration.new(database: :cache, databases: [:cache1])
    end
    assert_equal "You can only specify one of :database, :databases, or :connects_to", error.message
  end
end
