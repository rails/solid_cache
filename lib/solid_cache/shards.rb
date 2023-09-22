require "solid_cache/maglev_hash"

module SolidCache
  class Shards
    attr_reader :names, :nodes, :consistent_hash

    def initialize(options)
      case options
      when Array, NilClass
        @names = options || SolidCache.all_shard_keys || [SolidCache::Record.default_shard]
        @nodes = @names.to_h { |name| [ name, name ] }
      when Hash
        @names = options.keys
        @nodes = options.invert
      end

      @consistent_hash = MaglevHash.new(@nodes.keys) if sharded?
    end

    def with_each
      return enum_for(:with_each) unless block_given?

      names.each do |name|
        with(name) do
          yield
        end
      end
    end

    def with(name)
      if name && name != Entry.current_shard
        Record.connected_to(shard: name) do
          yield
        end
      else
        yield
      end
    end

    def with_shard_for(key)
      with(shard_for(key)) do
        yield
      end
    end

    def assign(list)
      if sharded?
        list.group_by { |value| shard_for(value.is_a?(Hash) ? value[:key] : value) }
      else
        { names.first => list }
      end
    end

    def count
      names.count
    end

    private
      def shard_for(key)
        if sharded?
          nodes[consistent_hash.node(key)]
        else
          names.first
        end
      end

      def sharded?
        names.count > 1
      end
  end
end
