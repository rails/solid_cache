module SolidCache
  class Cluster
    module Execution
      def initialize(options = {})
        super(options)
        @background = Concurrent::SingleThreadExecutor.new(max_queue: 100, fallback_policy: :discard)
        @active_record_instrumentation = options.fetch(:active_record_instrumentation, true)
      end

      private
        def async(&block)
          # Need current shard right now, not when block is called
          current_shard = Entry.current_shard
          @background << ->() do
            wrap_in_rails_executor do
              connections.with(current_shard) do
                instrument(&block)
              end
            end
          end
        end

        def execute(async, &block)
          if async
            async(&block)
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

        def active_record_instrumentation?
          @active_record_instrumentation
        end

        def instrument(&block)
          if active_record_instrumentation?
            block.call
          else
            Record.disable_instrumentation(&block)
          end
        end
    end
  end
end
