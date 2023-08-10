require "test_helper"
require "active_support/testing/method_call_assertions"

class SolidCache::MaglevHashTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  test "two nodes" do
    maglev_hash = SolidCache::MaglevHash.new([ :node1, :node2 ])
    results = nodes_for_1_to_30(maglev_hash)

    assert_equal [ 3, 5, 8, 11, 12, 14, 18, 19, 20, 22, 27, 28, 29 ], results[:node1]
    assert_equal [ 1, 2, 4, 6, 7, 9, 10, 13, 15, 16, 17, 21, 23, 24, 25, 26, 30 ], results[:node2]
  end

  test "three nodes" do
    maglev_hash = SolidCache::MaglevHash.new([ :node1, :node2, :node3 ])
    results = nodes_for_1_to_30(maglev_hash)

    assert_equal [ 5, 18, 20, 22, 27, 28, 29 ], results[:node1]
    assert_equal [ 1, 2, 4, 7, 9, 10, 13, 15, 21, 23, 26, 30 ], results[:node2]
    assert_equal [ 3, 6, 8, 11, 12, 14, 16, 17, 19, 24, 25 ], results[:node3]
  end

  test "four nodes" do
    maglev_hash = SolidCache::MaglevHash.new([ :node1, :node2, :node3, :node4 ])
    results = nodes_for_1_to_30(maglev_hash)

    assert_equal [ 5, 18, 20, 27, 29 ], results[:node1]
    assert_equal [ 1, 2, 4, 7, 9, 10, 13, 21, 23, 26, 30 ], results[:node2]
    assert_equal [ 6, 14, 16, 17, 19, 24, 25 ], results[:node3]
    assert_equal [ 3, 8, 11, 12, 15, 22, 28 ], results[:node4]
  end

  test "five nodes" do
    maglev_hash = SolidCache::MaglevHash.new([ :node1, :node2, :node3, :node4, :node5 ])
    results = nodes_for_1_to_30(maglev_hash)

    assert_equal [ 5, 18, 27, 29 ], results[:node1]
    assert_equal [ 1, 2, 4, 9, 10, 13, 21, 23, 26, 30 ], results[:node2]
    assert_equal [ 6, 14, 16, 17, 19, 25 ], results[:node3]
    assert_equal [ 8, 11, 12, 15, 22, 28 ], results[:node4]
    assert_equal [ 3, 7, 20, 24 ], results[:node5]
  end

  test "node count limits" do
    assert_raises(ArgumentError) { SolidCache::MaglevHash.new([]) }
    assert_nothing_raised { SolidCache::MaglevHash.new(2053.times.map(&:to_s)) }
    assert_raises(ArgumentError) { SolidCache::MaglevHash.new(2054.times.map(&:to_s)) }
  end

  private
    def nodes_for_1_to_30(maglev_hash)
      results = Hash.new { |hash, key| hash[key] = [] }
      (1..30).each { |key| results[maglev_hash.node(key)] << key }
      results
    end
end
