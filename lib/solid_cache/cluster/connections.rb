module SolidCache
  class Cluster
    module Connections
      def initialize(options = {})
        super(options)
        @shard_options = options.fetch(:shards, nil)

        if [Hash, Array, NilClass].none? { |klass| @shard_options.is_a? klass }
          raise ArgumentError, "`shards` is a `#{@shard_options.class.name}`, it should be one of Array, Hash or nil"
        end
      end

      def with_each_connection(async: false, &block)
        return enum_for(:with_each_connection) unless block_given?

        connections.with_each do
          async_if_required(async, &block)
        end
      end

      def with_connection_for(key, async: false, &block)
        connections.with_connection_for(key) do
          async_if_required(async, &block)
        end
      end

      def with_connection(name, async: false, &block)
        connections.with(name) do
          async_if_required(async, &block)
        end
      end

      def group_by_connection(keys)
        connections.assign(keys)
      end

      def connection_names
        connections.names
      end

      private
        def setup!
          connections
        end

        def connections
          @connections ||= SolidCache::Connections.from_config(@shard_options)
        end
    end
  end
end
