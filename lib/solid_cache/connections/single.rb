module SolidCache
  module Connections
    class Single
      attr_reader :name

      def initialize(name)
        @name = name
      end

      def with_each(&block)
        return enum_for(:with_each) unless block_given?

        with(name, &block)
      end

      def with(name, &block)
        Record.with_shard(name, &block)
      end

      def with_connection_for(_key, &block)
        with(name, &block)
      end

      def assign(keys)
        { name => keys }
      end

      def count
        1
      end

      def names
        [ name ]
      end
    end
  end
end
