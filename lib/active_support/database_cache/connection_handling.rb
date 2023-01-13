require "active_support/database_cache/hash_ring"

module ActiveSupport
  module DatabaseCache
    module ConnectionHandling
      def initialize(options = {})
        super(options)
        role = options.delete(:role)
        @writing_role = options.delete(:writing_role) || role
        @reading_role = options.delete(:reading_role) || role
        @shards = options[:shards] || [Entry.default_shard]
        @hash_ring = @shards.count > 0 ? HashRing.new(@shards) : nil
      end

      private
        def writing_all_shards
          @shards.each do |shard|
            with_role_and_shard(role: @writing_role, shard: shard) { yield }
          end
        end

        def writing_across_shards(list:)
          across_shards(role: @writing_role, list:) { |list| yield list }
        end

        def reading_across_shards(list:)
          across_shards(role: @reading_role, list:) { |list| yield list }
        end

        def writing_shard(key:)
          with_role_and_shard(role: @writing_role, shard: shard_for(key)) { yield }
        end

        def reading_shard(key:)
          with_role_and_shard(role: @reading_role, shard: shard_for(key)) { yield }
        end

        def with_role_and_shard(role:, shard:)
          if role || shard
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

        def in_shards(values)
          values.group_by { |value| shard_for(value.is_a?(Hash) ? value[:key] : value) }
        end

        def shard_for(key)
          @hash_ring&.get_node(key) || @shards.first
        end
    end
  end
end
