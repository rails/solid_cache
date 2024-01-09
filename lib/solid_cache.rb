# frozen_string_literal: true

require "zeitwerk"
require "solid_cache/engine"

loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/active_support")
loader.ignore("#{__dir__}/generators")
loader.setup

module SolidCache
  mattr_accessor :executor, :connects_to
  mattr_accessor :key_hash_stage, default: :indexed

  def self.all_shard_keys
    all_shards_config&.keys || []
  end

  def self.all_shards_config
    connects_to && connects_to[:shards]
  end

  def self.each_shard(&block)
    return to_enum(:each_shard) unless block_given?

    if (shards = all_shards_config&.keys)
      shards.each do |shard|
        Record.with_shard(shard, &block)
      end
    else
      yield
    end
  end
end

loader.eager_load
