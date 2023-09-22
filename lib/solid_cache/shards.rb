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

    def with_each(&block)
      return enum_for(:with_each) unless block_given?

      names.each { |name| with(name, &block) }
    end

    def with(name, &block)
      Record.with_shard(name, &block)
    end

    def with_shard_for(key, &block)
      with(shard_for(key), &block)
    end

    def assign(keys)
      if sharded?
        keys.group_by { |key| shard_for(key.is_a?(Hash) ? key[:key] : key) }
      else
        { names.first => keys }
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
