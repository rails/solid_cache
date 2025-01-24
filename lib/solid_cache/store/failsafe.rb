# frozen_string_literal: true

module SolidCache
  class Store
    module Failsafe
      TRANSIENT_ACTIVE_RECORD_ERRORS = [
        ActiveRecord::AdapterTimeout,
        ActiveRecord::ConnectionNotEstablished,
        ActiveRecord::Deadlocked,
        ActiveRecord::LockWaitTimeout,
        ActiveRecord::QueryCanceled,
        ActiveRecord::StatementTimeout
      ]

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
        rescue *TRANSIENT_ACTIVE_RECORD_ERRORS => error
          ActiveSupport.error_reporter&.report(error, handled: true, severity: :warning)
          error_handler&.call(method: method, exception: error, returning: returning)
          returning
        end
    end
  end
end
