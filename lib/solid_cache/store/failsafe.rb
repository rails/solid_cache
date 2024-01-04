# frozen_string_literal: true

module SolidCache
  class Store
    module Failsafe
      DEFAULT_ERROR_HANDLER = ->(method:, returning:, exception:) do
        if Store.logger
          Store.logger.error { "SolidCacheStore: #{method} failed, returned #{returning.inspect}: #{exception.class}: #{exception.message}" }
        end
      end

      def initialize(options = {})
        super(options)

        @error_handler = options.fetch(:error_handler, DEFAULT_ERROR_HANDLER)
      end

      private
        attr_reader :error_handler

        def failsafe(method, returning: nil)
          yield
        rescue ActiveRecord::ActiveRecordError => error
          ActiveSupport.error_reporter&.report(error, handled: true, severity: :warning)
          error_handler&.call(method: method, exception: error, returning: returning)
          returning
        end
    end
  end
end
