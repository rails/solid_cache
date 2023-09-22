module SolidCache
  class Cluster
    module Sharded
      def initialize(options = {})
        super(options)
        @shard_options = options.fetch(:shards, nil)

        if [Hash, Array, NilClass].none? { |klass| @shard_options.is_a? klass }
          raise ArgumentError, "`shards` is a `#{shards.class.name}`, it should be one of Array, Hash or nil"
        end
      end

      def with_each_shard(async: false)
        return enum_for(:with_each_shard) unless block_given?

        shards.with_each do
          async_if_required(async) do
            yield
          end
        end
      end

      def with_shard_for(key, async: false)
        shards.with_shard_for(key) do
          async_if_required(async) do
            yield
          end
        end
      end

      def with_shard(name, async: false)
        shards.with(name) do
          async_if_required(async) do
            yield
          end
        end
      end

      def assign_to_shards(keys)
        shards.assign(keys)
      end

      def shard_names
        shards.names
      end

      private
        def setup_shards!
          return if defined?(@shards)
          @shards = Shards.new(@shard_options)
        end

        def shards
          setup_shards! unless defined?(@shards)
          @shards
        end
    end
  end
end
