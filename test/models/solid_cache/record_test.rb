require "test_helper"

module SolidCache
  class RecordTest < ActiveSupport::TestCase
    test "set and get cache entries" do
      shards = SolidCache::Record.each_shard.map { SolidCache::Record.current_shard }
      assert_equal [ :default, :default2, :primary_shard_one, :primary_shard_two, :secondary_shard_one, :secondary_shard_two ], shards
    end
  end
end
