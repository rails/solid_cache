module ActiveSupport
  module DatabaseCache
    module AsyncExecution
      def initialize(options)
        super(options)
        @executor = Concurrent::SingleThreadExecutor.new(max_queue: 100, fallback_policy: :discard)
      end

      private
        def async(&block)
          @executor << block
        end
    end
  end
end
