# frozen_string_literal: true

require "test_helper"

module SolidCache
  class RecordTest < ActiveSupport::TestCase
    SINGLE_DB_CONFIGS = [ "config/solid_cache_database.yml", "config/solid_cache_unprepared_statements.yml" ]
    MULTI_DB_CONFIGS = [
      "config/solid_cache_connects_to.yml",
      "config/solid_cache_encrypted.yml",
      "config/solid_cache_encrypted_custom.yml",
      "config/solid_cache_shards.yml",
      nil
    ]

    test "each_shard" do
      shards = SolidCache::Record.each_shard.map { SolidCache::Record.current_shard }
      case ENV["SOLID_CACHE_CONFIG"]
      when "config/solid_cache_no_database.yml"
        assert_equal [ :default ], shards
      when "config/solid_cache_database.yml"
        assert_equal [ :primary ], shards
      when "config/solid_cache_unprepared_statements.yml"
        assert_equal [ :primary_unprepared_statements ], shards
      when *MULTI_DB_CONFIGS
        assert_equal [ :primary_shard_one, :primary_shard_two, :secondary_shard_one, :secondary_shard_two ], shards
      else
        raise "Unknown SOLID_CACHE_CONFIG: #{ENV["SOLID_CACHE_CONFIG"]}"
      end
    end

    test "each_shard uses the default role" do
      role = ActiveRecord::Base.connected_to(role: :reading) { SolidCache::Record.each_shard.map { SolidCache::Record.current_role } }
      case ENV["SOLID_CACHE_CONFIG"]
      when "config/solid_cache_no_database.yml"
        assert_equal [ :reading ], role
      when *SINGLE_DB_CONFIGS
        assert_equal [ :writing ], role
      when *MULTI_DB_CONFIGS
        assert_equal [ :writing, :writing, :writing, :writing ], role
      else
        raise "Unknown SOLID_CACHE_CONFIG: #{ENV["SOLID_CACHE_CONFIG"]}"
      end
    end
  end
end
