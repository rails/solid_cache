# frozen_string_literal: true

require "test_helper"

module SolidCache
  class RecordTest < ActiveSupport::TestCase
    test "each_shard" do
      shards = SolidCache::Record.each_shard.map { SolidCache::Record.current_shard }
      case ENV["SOLID_CACHE_CONFIG"]
      when "config/solid_cache_no_database.yml", "config/solid_cache_database.yml"
        assert_equal [ :default ], shards
      when "config/solid_cache_clusters.yml", "config/solid_cache_clusters_named.yml", nil
        assert_equal [ :primary_shard_one, :primary_shard_two, :secondary_shard_one, :secondary_shard_two ], shards
      when "config/solid_cache_cluster.yml", "config/solid_cache_cluster_inferred.yml"
        assert_equal [ :primary_shard_one, :primary_shard_two ], shards
      else
        raise "Unknown SOLID_CACHE_CONFIG: #{ENV["SOLID_CACHE_CONFIG"]}"
      end
    end

    test "each_shard uses the default role" do
      role = ActiveRecord::Base.connected_to(role: :reading) { SolidCache::Record.each_shard.map { SolidCache::Record.current_role } }
      case ENV["SOLID_CACHE_CONFIG"]
      when "config/solid_cache_no_database.yml", "config/solid_cache_database.yml"
        assert_equal [ :reading ], role
      when "config/solid_cache_clusters.yml", "config/solid_cache_clusters_named.yml", nil
        assert_equal [ :writing, :writing, :writing, :writing ], role
      when "config/solid_cache_cluster.yml", "config/solid_cache_cluster_inferred.yml"
        assert_equal [ :writing, :writing ], role
      else
        raise "Unknown SOLID_CACHE_CONFIG: #{ENV["SOLID_CACHE_CONFIG"]}"
      end
    end
  end
end
