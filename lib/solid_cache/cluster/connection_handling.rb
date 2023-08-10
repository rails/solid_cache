module SolidCache
  class Cluster
    module ConnectionHandling
      attr_reader :async_writes

      def initialize(options = {})
        super(options)
        @shards = options.delete(:shards)
        @async_writes = options.delete(:async_writes)
      end

      def writing_all_shards
        return enum_for(:writing_all_shards) unless block_given?

        shards.each do |shard|
          with_shard(shard) do
            async_if_required { yield }
          end
        end
      end

      def shards
        @shards || SolidCache.all_shard_keys || [nil]
      end

      def writing_across_shards(list:, trim: false)
        across_shards(list:) do |list|
          async_if_required do
            result = yield list
            trim(list.size) if trim
            result
          end
        end
      end

      def reading_across_shards(list:)
        across_shards(list:) { |list| yield list }
      end

      def writing_shard(normalized_key:, trim: false)
        with_shard(shard_for_normalized_key(normalized_key)) do
          async_if_required do
            result = yield
            trim(1) if trim
            result
          end
        end
      end

      def reading_shard(normalized_key:)
        with_shard(shard_for_normalized_key(normalized_key)) { yield }
      end

      private
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

        def async_if_required
          if async_writes
            async { yield }
          else
            yield
          end
        end
    end
  end
end
