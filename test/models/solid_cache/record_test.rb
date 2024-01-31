# frozen_string_literal: true

require "test_helper"

module SolidCache
  class RecordTest < ActiveSupport::TestCase
    test "each_shard" do
      shards = SolidCache::Record.each_shard.map { SolidCache::Record.current_shard }
      if ENV["NO_CONNECTS_TO"]
        assert_equal [ :default ], shards
      else
        assert_equal [ :default, :primary_shard_one, :primary_shard_two, :secondary_shard_one, :secondary_shard_two ], shards
      end
    end

    test "each_shard uses the default role" do
      role = ActiveRecord::Base.connected_to(role: :reading) { SolidCache::Record.each_shard.map { SolidCache::Record.current_role } }
      if ENV["NO_CONNECTS_TO"]
        assert_equal [ :reading ], role
      else
        assert_equal [ :writing, :writing, :writing, :writing, :writing ], role
      end
    end
  end
end
