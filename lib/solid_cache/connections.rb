# frozen_string_literal: true

module SolidCache
  module Connections
    def self.from_config(options)
      if options.present? || SolidCache.all_shards_config.present?
        case options
        when NilClass
          names = SolidCache.all_shard_keys
          nodes = names.to_h { |name| [ name, name ] }
        when Array
          names = options
          nodes = names.to_h { |name| [ name, name ] }
        when Hash
          names = options.keys
          nodes = options.invert
        end

        if (unknown_shards = names - SolidCache.all_shard_keys).any?
          raise ArgumentError, "Unknown #{"shard".pluralize(unknown_shards)}: #{unknown_shards.join(", ")}"
        end

        if names.size == 1
          Single.new(names.first)
        else
          Sharded.new(names, nodes)
        end
      else
        Unmanaged.new
      end
    end
  end
end
