# frozen_string_literal: true

module SolidCache
  class Configuration
    attr_accessor :store_options, :connects_to, :key_hash_stage, :executor

    def initialize
      self.store_options = {}
      self.connects_to = nil
      self.key_hash_stage = :indexed
      self.executor = nil
    end

    def set_options(options)
      options.each do |key, value|
        public_send("#{key}=", value)
      end
    end

    def connects_to_config
      if connects_to
        {
          shards: connects_to[:shards].to_h { |shard, config| [ shard, config || { writing: shard } ] },
        }
      end
    end

    def sharded?
      !!connects_to
    end

    def shard_keys
      if connects_to
        connects_to[:shards].keys
      else
        []
      end
    end
  end
end
