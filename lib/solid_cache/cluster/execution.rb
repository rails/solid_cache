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
              shards.with(current_shard) do
                block.call(current_shard)
              end
            end
          end
        end

        def async_if_required(required)
          if required
            async { instrument { yield } }
          else
            instrument { yield }
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
