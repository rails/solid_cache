module SolidCache
  module Connections
    class Unmanaged
      def with_each(&block)
        return enum_for(:with_each) unless block_given?

        yield
      end

      def with(name)
        yield
      end

      def with_connection_for(key, &block)
        yield
      end

      def assign(keys)
        { :default => keys }
      end

      def count
        1
      end

      def names
        [ :default ]
      end
    end
  end
end
