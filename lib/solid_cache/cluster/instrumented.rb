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
        def instrument
          if active_record_instrumentation?
            yield
          else
            Record.disable_instrumentation do
              yield
            end
          end
        end
    end
  end
end
