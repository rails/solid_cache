# frozen_string_literal: true

module SolidCache
  class Store
    module Execution
      def initialize(options = {})
        super(options)
        @background = Concurrent::FixedThreadPool.new(1, max_queue: 100, fallback_policy: :discard)
        @active_record_instrumentation = options.fetch(:active_record_instrumentation, true)
      end

      private
        def async(&block)
          # Need current shard right now, not when block is called
          current_shard = Entry.current_shard
          @background << ->() do
            wrap_in_rails_executor do
              connections.with(current_shard) do
                setup_instrumentation(&block)
              end
            end
          rescue Exception => exception
            error_handler&.call(method: :async, exception: exception, returning: nil)
          end
        end

        def execute(async, &block)
          if async
            async(&block)
          else
            setup_instrumentation(&block)
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

        def setup_instrumentation(&block)
          if active_record_instrumentation?
            block.call
          else
            Record.disable_instrumentation(&block)
          end
        end
    end
  end
end
