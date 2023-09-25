module SolidCache
  class Cluster
    module Execution
      def initialize(options = {})
        super(options)
        @background = Concurrent::SingleThreadExecutor.new(max_queue: 100, fallback_policy: :discard)
      end

      private
        def async(&block)
          # Need current shard right now, not when block is called
          current_shard = Entry.current_shard
          @background << ->() do
            wrap_in_rails_executor do
              connections.with(current_shard, &block)
            end
          end
        end

        def async_if_required(required, &block)
          if required
            async { instrument(&block) }
          else
            instrument(&block)
          end
        end

        def wrap_in_rails_executor(&block)
          if SolidCache.executor
            SolidCache.executor.wrap(&block)
          else
            block.call
          end
        end
    end
  end
end
