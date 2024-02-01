# frozen_string_literal: true

module SolidCache
  class Cluster
    module Connections
      attr_reader :shard_options

      def initialize(options = {})
        super(options)
        @shard_options = options.fetch(:shards, nil)

        if [ Hash, Array, NilClass ].none? { |klass| @shard_options.is_a? klass }
          raise ArgumentError, "`shards` is a `#{@shard_options.class.name}`, it should be one of Array, Hash or nil"
        end
      end

      def with_each_connection(async: false, &block)
        return enum_for(:with_each_connection) unless block_given?

        connections.with_each do
          execute(async, &block)
        end
      end

      def with_connection_for(key, async: false, &block)
        connections.with_connection_for(key) do
          execute(async, &block)
        end
      end

      def with_connection(name, async: false, &block)
        connections.with(name) do
          execute(async, &block)
        end
      end

      def group_by_connection(keys)
        connections.assign(keys)
      end

      def connection_names
        connections.names
      end

      def connections
        @connections ||= SolidCache::Connections.from_config(@shard_options)
      end

      private
        def setup!
          connections
        end
    end
  end
end
