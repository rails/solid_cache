module SolidCache
  class Cluster
    module AsyncExecution
      def initialize(options)
        super()
        @executor = Concurrent::SingleThreadExecutor.new(max_queue: 100, fallback_policy: :discard)
      end

      private
        def async(&block)
          @executor << ->() do
            wrap_in_rails_executor do
              block.call
            end
          end
        end

        def async_on_current_shard(&block)
          shard = Entry.current_shard
          async do
            execute_on_shard(shard) { block.call }
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
end
