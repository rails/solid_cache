require "zeitwerk"

loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/active_support")
loader.ignore("#{__dir__}/generators")
loader.setup
loader.eager_load

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
