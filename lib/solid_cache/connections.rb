# frozen_string_literal: true

module SolidCache
  module Connections
    def self.from_config(options)
      if options.present? || SolidCache.configuration.sharded?
        case options
        when NilClass
          names = SolidCache.configuration.shard_keys
        when Array
          names = options.map(&:to_sym)
        end

        if (unknown_shards = names - SolidCache.configuration.shard_keys).any?
          raise ArgumentError, "Unknown #{"shard".pluralize(unknown_shards)}: #{unknown_shards.join(", ")}"
        end

        if names.size == 1
          Single.new(names.first)
        else
          Sharded.new(names)
        end
      else
        Unmanaged.new
      end
    end
  end
end
