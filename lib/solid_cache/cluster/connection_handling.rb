require "solid_cache/maglev_hash"

module SolidCache
  class Cluster
    module ConnectionHandling
      attr_reader :async_writes

      def initialize(options = {})
        super(options)
        @async_writes = options.fetch(:async_writes, false)
        @shard_options = options.fetch(:shards, nil)
        @active_record_instrumentation = options.fetch(:active_record_instrumentation, true)

        if [Hash, Array, NilClass].none? { |klass| @shard_options.is_a? klass }
          raise ArgumentError, "`shards` is a `#{shards.class.name}`, it should be one of Array, Hash or nil"
        end

        # Done lazily as the cache maybe created before ActionRecord initialization
        @setup = false
      end

      def setup?
        @setup
      end

      def setup!
        return if setup?

        case @shard_options
        when Array, NilClass
          @shards = @shard_options || SolidCache.all_shard_keys || []
          @nodes = @shards.to_h { |shard| [ shard, shard ] }
        when Hash
          @shards = @shard_options.keys
          @nodes = @shard_options.invert
        end

        if @shards.count > 1
          @consistent_hash = MaglevHash.new(@nodes.keys)
        end

        @setup = true
      end

      def shards
        setup!

        @shards
      end

      def nodes
        setup!

        @nodes
      end

      def writing_all_shards
        return enum_for(:writing_all_shards) unless block_given?

        shards.each do |shard|
          with_shard(shard) do
            async_if_required { yield }
          end
        end
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

      def active_record_instrumentation?
        @active_record_instrumentation
      end

      private
        attr_reader :consistent_hash

        def with_shard(shard)
          if shard
            Record.connected_to(shard: shard) do
              disable_active_record_instrumentation_if_required do
                yield
              end
            end
          else
            disable_active_record_instrumentation_if_required do
              yield
            end
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
          return shards.first if shards.count <= 1

          node = consistent_hash.node(normalized_key)
          nodes[node]
        end

        def async_if_required
          if async_writes
            async { yield }
          else
            yield
          end
        end

        def disable_active_record_instrumentation_if_required
          if active_record_instrumentation?
            yield
          else
            Record.disable_instrumentation do
              yield
            end
          end
        end
    end
  end
end
