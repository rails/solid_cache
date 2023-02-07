require "test_helper"

module SolidCache
  class RecordTest < ActiveSupport::TestCase
    test "set and get cache entries" do
      shards = SolidCache::Record.each_shard.map { SolidCache::Record.current_shard }
      assert_equal [ :default, :shard_one ], shards
    end
  end
end
