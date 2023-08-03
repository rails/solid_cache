module SolidCache
  module AsyncExecution
    def initialize(options)
      super(options)
      @executor = Concurrent::SingleThreadExecutor.new(max_queue: 100, fallback_policy: :discard)
    end

    private
      def async(&block)
        # Need current shard right now, not when block is called
        current_shard = Entry.current_shard
        @executor << ->() do
          wrap_in_rails_executor do
            with_shard(current_shard) do
              block.call(current_shard)
            end
          end
        end
      end

      def wrap_in_rails_executor
        if SolidCache.executor
          SolidCache.executor.wrap { yield }
        else
          yield
        end
      end
  end
end
