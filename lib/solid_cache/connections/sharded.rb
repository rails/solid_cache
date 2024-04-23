# frozen_string_literal: true

module SolidCache
  module Connections
    class Sharded
      attr_reader :names, :nodes, :consistent_hash

      def initialize(names)
        @names = names
        @consistent_hash = MaglevHash.new(names)
      end

      def with_each(&block)
        return enum_for(:with_each) unless block_given?

        names.each { |name| with(name, &block) }
      end

      def with(name, &block)
        Record.with_shard(name, &block)
      end

      def with_connection_for(key, &block)
        with(shard_for(key), &block)
      end

      def assign(keys)
        keys.group_by { |key| shard_for(key.is_a?(Hash) ? key[:key] : key) }
      end

      def count
        names.count
      end

      private
        def shard_for(key)
          consistent_hash.node(key)
        end
    end
  end
end
