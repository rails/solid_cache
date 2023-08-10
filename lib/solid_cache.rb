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

  def self.shard_databases
    @shard_databases ||= each_shard.map.to_h { [ Record.current_shard, Record.connection_db_config.database ] }
  end

  def self.each_shard
    return to_enum(:each_shard) unless block_given?

    if (shards = connects_to[:shards]&.keys)
      shards.each do |shard|
        Record.connected_to(shard: shard) { yield }
      end
    else
      yield
    end
  end
end
