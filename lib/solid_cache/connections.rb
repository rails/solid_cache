# frozen_string_literal: true

module SolidCache
  module Connections
    def self.from_config(options)
      if options.present? || SolidCache.configuration.sharded?
        case options
        when NilClass
          names = SolidCache.configuration.shard_keys
          nodes = names.to_h { |name| [ name, name ] }
        when Array
          names = options.map(&:to_sym)
          nodes = names.to_h { |name| [ name, name ] }
        when Hash
          names = options.keys.map(&:to_sym)
          nodes = options.to_h { |names, nodes| [ nodes.to_sym, names.to_sym ] }
        end

        if (unknown_shards = names - SolidCache.configuration.shard_keys).any?
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
