# frozen_string_literal: true

module SolidCache
  class Store
    module Connections
      attr_reader :shard_options

      def initialize(options = {})
        super(options)
        if options[:clusters].present?
          if options[:clusters].size > 1
            raise ArgumentError, "Multiple clusters are no longer supported"
          else
            ActiveSupport.deprecator.warn(":clusters is deprecated, use :shards instead.")
          end
          @shard_options = options.fetch(:clusters).first[:shards]
        elsif options[:cluster].present?
          ActiveSupport.deprecator.warn(":cluster is deprecated, use :shards instead.")
          @shard_options = options.fetch(:cluster, {})[:shards]
        else
          @shard_options = options.fetch(:shards, nil)
        end

        if [ Array, NilClass ].none? { |klass| @shard_options.is_a? klass }
          raise ArgumentError, "`shards` is a `#{@shard_options.class.name}`, it should be Array or nil"
        end
      end

      def with_each_connection(async: false, &block)
        return enum_for(:with_each_connection) unless block_given?

        connections.with_each do
          execute(async, &block)
        end
      end

      def connections
        @connections ||= SolidCache::Connections.from_config(@shard_options)
      end

      private
        def setup!
          connections
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

        def reading_key(key, failsafe:, failsafe_returning: nil, &block)
          failsafe(failsafe, returning: failsafe_returning) do
            with_connection_for(key, &block)
          end
        end

        def reading_keys(keys, failsafe:, failsafe_returning: nil)
          group_by_connection(keys).map do |connection, grouped_keys|
            failsafe(failsafe, returning: failsafe_returning) do
              with_connection(connection) do
                yield grouped_keys
              end
            end
          end
        end

        def writing_key(key, failsafe:, failsafe_returning: nil, &block)
          failsafe(failsafe, returning: failsafe_returning) do
            with_connection_for(key, &block)
          end
        end

        def writing_keys(entries, failsafe:, failsafe_returning: nil)
          group_by_connection(entries).map do |connection, grouped_entries|
            failsafe(failsafe, returning: failsafe_returning) do
              with_connection(connection) do
                yield grouped_entries
              end
            end
          end
        end

        def writing_all(failsafe:, failsafe_returning: nil, &block)
          connection_names.map do |connection|
            failsafe(failsafe, returning: failsafe_returning) do
              with_connection(connection, &block)
            end
          end.first
        end
    end
  end
end
