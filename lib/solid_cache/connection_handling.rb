require "solid_cache/hash_ring"

module SolidCache
  module ConnectionHandling
    def initialize(options = {})
      super(options)
      @shards = options.delete(:shards)
    end

    def writing_all_shards
      return enum_for(:writing_all_shards) unless block_given?

      shards.each do |shard|
        with_shard(shard) { yield }
      end
    end

    def shards
      @shards || SolidCache.all_shard_keys || [nil]
    end

    private
      def writing_across_shards(list:)
        across_shards(list:) { |list| yield list }
      end

      def reading_across_shards(list:)
        across_shards(list:) { |list| yield list }
      end

      def with_shard_for_key(normalized_key:)
        with_shard(shard_for_normalized_key(normalized_key)) { yield }
      end

      def with_shard(shard)
        if shard
          Record.connected_to(shard: shard) { yield }
        else
          yield
        end
      end

      def across_shards(list:)
        in_shards(list).map do |shard, list|
          with_shard(shard) { yield list }
        end
      end

      def in_shards(list)
        if shards.count == 1
          { shards.first => list }
        else
          list.group_by { |value| shard_for_normalized_key(value.is_a?(Hash) ? value[:key] : value) }
        end
      end

      def shard_for_normalized_key(normalized_key)
        hash_ring&.get_node(normalized_key) || shards&.first
      end

      def hash_ring
        @hash_ring ||= shards.count > 0 ? HashRing.new(shards) : nil
      end
  end
end
