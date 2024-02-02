# frozen_string_literal: true

require "test_helper"

class ClusterTest < ActiveSupport::TestCase
  setup do
    skip unless multi_cluster?

    @cache = nil
    @namespace = "test-#{SecureRandom.hex}"

    @cache = lookup_store(expires_in: 60)
    p
    @primary_cache = lookup_store(expires_in: 60, clusters: [{ shards: @cache.clusters.first.shard_options }])
    @secondary_cache = lookup_store(expires_in: 60, clusters: [{ shards: @cache.clusters.second.shard_options }])
  end

  teardown do
    wait_for_background_tasks(@cache) if @cache
  end

  test "writes to both clusters" do
    @cache.write("foo", 1)
    wait_for_background_tasks(@cache)
    assert_equal 1, @cache.read("foo")
    assert_equal 1, @primary_cache.read("foo")
    assert_equal 1, @secondary_cache.read("foo")
  end

  test "reads from primary cluster" do
    @cache.write("foo", 1)
    wait_for_background_tasks(@cache)
    assert_equal 1, @cache.read("foo")

    @secondary_cache.delete("foo")
    assert_equal 1, @cache.read("foo")

    @primary_cache.delete("foo")
    assert_nil @cache.read("foo")
  end

  test "fetch writes to both clusters" do
    @cache.fetch("foo") { 1 }
    wait_for_background_tasks(@cache)

    assert_equal 1, @cache.read("foo")
    assert_equal 1, @primary_cache.read("foo")
    assert_equal 1, @secondary_cache.read("foo")
  end

  test "fetch reads from primary clusters" do
    @cache.fetch("foo") { 1 }
    wait_for_background_tasks(@cache)
    assert_equal 1, @cache.read("foo")

    @primary_cache.delete("foo")
    @cache.fetch("foo") { 2 }
    wait_for_background_tasks(@cache)

    assert_equal 2, @cache.read("foo")
    assert_equal 2, @primary_cache.read("foo")
    assert_equal 2, @secondary_cache.read("foo")

    @secondary_cache.delete("foo")
    assert_equal 2, @cache.fetch("foo") { 3 }

    assert_equal 2, @primary_cache.read("foo")
    assert_nil @secondary_cache.read("foo")
  end

  test "deletes from both cluster" do
    @cache.write("foo", 1)
    wait_for_background_tasks(@cache)
    assert_equal 1, @cache.read("foo")

    @cache.delete("foo")
    wait_for_background_tasks(@cache)

    assert_nil @cache.read("foo")
    assert_nil @primary_cache.read("foo")
    assert_nil @secondary_cache.read("foo")
  end

  test "multi_writes to both clusters" do
    values = { "foo" => "bar", "egg" => "spam" }
    @cache.write_multi(values)
    wait_for_background_tasks(@cache)
    assert_equal values, @cache.read_multi("foo", "egg")
    assert_equal values, @primary_cache.read_multi("foo", "egg")
    assert_equal values, @secondary_cache.read_multi("foo", "egg")
  end

  test "increment and decrement hit both clusters" do
    @cache.write("foo", 1, raw: true)
    wait_for_background_tasks(@cache)

    assert_equal 1, @cache.read("foo", raw: true).to_i
    assert_equal 1, @primary_cache.read("foo", raw: true).to_i
    assert_equal 1, @secondary_cache.read("foo", raw: true).to_i

    @cache.increment("foo")
    wait_for_background_tasks(@cache)

    assert_equal 2, @cache.read("foo", raw: true).to_i
    assert_equal 2, @primary_cache.read("foo", raw: true).to_i
    assert_equal 2, @secondary_cache.read("foo", raw: true).to_i

    @secondary_cache.write("foo", 4, raw: true)

    @cache.decrement("foo")
    wait_for_background_tasks(@cache)

    assert_equal 1, @cache.read("foo", raw: true).to_i
    assert_equal 1, @primary_cache.read("foo", raw: true).to_i
    assert_equal 3, @secondary_cache.read("foo", raw: true).to_i
  end

  test "cache with node names" do
    @namespace = "test-#{SecureRandom.hex}"
    primary_cluster = { shards: { primary_shard_one: :node1, primary_shard_two: :node2 } }
    secondary_cluster = { shards: { secondary_shard_one: :node3, secondary_shard_two: :node4 } }

    @cache = lookup_store(expires_in: 60, clusters: [ primary_cluster, secondary_cluster ])
    @primary_cache = lookup_store(expires_in: 60, clusters: [ primary_cluster ])
    @secondary_cache = lookup_store(expires_in: 60, clusters: [ secondary_cluster ])

    @cache.write("foo", 1)
    wait_for_background_tasks(@cache)
    assert_equal 1, @cache.read("foo")
    assert_equal 1, @primary_cache.read("foo")
    assert_equal 1, @secondary_cache.read("foo")

    assert_equal [ :node1, :node2 ], @cache.primary_cluster.connections.consistent_hash.nodes
    assert_equal [ :node3, :node4 ], @cache.clusters[1].connections.consistent_hash.nodes
  end
end
