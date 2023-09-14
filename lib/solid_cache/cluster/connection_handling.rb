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
          # Using a dedicated thread for each shard avoids ActiveRecord connection switching
          # Connection switching is expensive because the connection is tested before being
          # checked out, which involves a round trip to the database.
          @executors = @shards.to_h { |shard| [shard, Concurrent::SingleThreadExecutor.new(max_queue: 10, fallback_policy: :caller_runs)] }
        else
          @executors = {}
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

      def writing_all_shards(&block)
        return enum_for(:writing_all_shards) unless block_given?

        shards \
          .map { |shard| with_shard(shard, async: async_writes, &block) }
          .then { |results| realise_all(results) }
      end

      def writing_across_shards(list:, trim: false)
        results = across_shards(list:, async: async_writes) do |list|
          result = yield list
          trim(list.size) if trim
          result
        end

        realise_all(results)
      end

      def reading_across_shards(list:)
        across_shards(list:) { |list| yield list }.then { |results| realise_all(results) }
      end

      def writing_shard(normalized_key:, trim: false)
        result = with_shard(shard_for_normalized_key(normalized_key), async: async_writes) do
          result = yield
          trim(1) if trim
          result
        end

        realise(result)
      end

      def reading_shard(normalized_key:)
        result = with_shard(shard_for_normalized_key(normalized_key)) { yield }
        realise(result)
      end

      def active_record_instrumentation?
        @active_record_instrumentation
      end

      private
        attr_reader :consistent_hash

        def with_shard(shard, async: false, &block)
          if async
            async { execute_on_shard(shard, &block) }
          elsif (executor = @executors[shard])
            with_executor(executor) { execute_on_shard(shard, &block) }
          else
            execute_on_shard(shard, &block)
          end
        end

        def across_shards(list:, async: false)
          in_shards(list).map do |shard, list|
            with_shard(shard, async: async) { yield list }
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

        def disable_active_record_instrumentation_if_required(&block)
          if active_record_instrumentation?
            block.call
          else
            Record.disable_instrumentation(&block)
          end
        end

        def execute_on_shard(shard, &block)
          if shard
            Record.connected_to(shard: shard) do
              disable_active_record_instrumentation_if_required(&block)
            end
          else
            disable_active_record_instrumentation_if_required(&block)
          end
        end

        def with_executor(executor, &block)
          Concurrent::Promise.execute(executor: executor, &block)
        end

        def realise(result)
          if result.is_a?(Concurrent::Promise)
            result.value.tap { raise result.reason if result.rejected? }
          else
            result
          end
        end

        def realise_all(results)
          results.map { |result| realise(result) }
        end
    end
  end
end
