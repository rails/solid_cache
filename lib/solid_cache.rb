require "solid_cache/version"
require "solid_cache/engine"
require "solid_cache/store"

module SolidCache
  mattr_accessor :executor, :connects_to

  def self.all_shard_keys
    all_shards_config&.keys
  end

  def self.all_shards_config
    connects_to && connects_to[:shards]
  end

  def self.shard_config(shard)
    all_shards_config && all_shards_config[shard]
  end
end
