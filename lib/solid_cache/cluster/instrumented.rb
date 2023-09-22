module SolidCache
  class Cluster
    module Instrumented
      def initialize(options = {})
        super(options)
        @active_record_instrumentation = options.fetch(:active_record_instrumentation, true)
      end

      def active_record_instrumentation?
        @active_record_instrumentation
      end

      private
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
