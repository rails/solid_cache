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
        with_role_and_shard(role: ActiveRecord.writing_role, shard: shard) { yield }
      end
    end

    def shards
      @shards || SolidCache.all_shard_keys || [nil]
    end

    private
      def writing_across_shards(list:)
        across_shards(role: ActiveRecord.writing_role, list:) { |list| yield list }
      end

      def reading_across_shards(list:)
        across_shards(role: ActiveRecord.reading_role, list:) { |list| yield list }
      end

      def writing_shard(normalized_key:)
        with_role_and_shard(role: ActiveRecord.writing_role, shard: shard_for_normalized_key(normalized_key)) { yield }
      end

      def reading_shard(normalized_key:)
        with_role_and_shard(role: ActiveRecord.reading_role, shard: shard_for_normalized_key(normalized_key)) { yield }
      end

      def with_role_and_shard(role:, shard:)
        if role || shard
          role ||= SolidCache.shard_first_role(shard)
          Record.connected_to(role: role, shard: shard) { yield }
        else
          yield
        end
      end

      def across_shards(role:, list:)
        in_shards(list).map do |shard, list|
          with_role_and_shard(role: role, shard: shard) { yield list }
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
