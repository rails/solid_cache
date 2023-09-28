require "concurrent/atomic/atomic_fixnum"

module SolidCache
  class Cluster
    module Expiry
      # For every write that we do, we attempt to delete EXPIRY_MULTIPLIER times as many records.
      # This ensures there is downward pressure on the cache size while there is valid data to delete
      EXPIRY_MULTIPLIER = 1.25

      attr_reader :expiry_batch_size, :expiry_method, :expire_every, :max_age, :max_entries

      def initialize(options = {})
        super(options)
        @expiry_batch_size = options.fetch(:expiry_batch_size, 100)
        @expiry_method = options.fetch(:expiry_method, :thread)
        @expire_every = [ (expiry_batch_size / EXPIRY_MULTIPLIER).floor, 1 ].max
        @max_age = options.fetch(:max_age, 2.weeks.to_i)
        @max_entries = options.fetch(:max_entries, nil)

        raise ArgumentError, "Expiry method must be one of `:thread` or `:job`" unless [ :thread, :job ].include?(expiry_method)
      end

      def track_writes(count)
        expire_later if expiry_counter.count(count)
      end

      private
        def expire_later
          if expiry_method == :job
            ExpiryJob.perform_later(expiry_batch_size, shard: Entry.current_shard, max_age: max_age, max_entries: max_entries)
          else
            async { Entry.expire(expiry_batch_size, max_age: max_age, max_entries: max_entries) }
          end
        end

        def expiry_counter
          @expiry_counters ||= connection_names.to_h { |connection_name| [ connection_name, Counter.new(expire_every) ] }
          @expiry_counters[Entry.current_shard]
        end

        class Counter
          attr_reader :expire_every, :counter

          def initialize(expire_every)
            @expire_every = expire_every
            @counter = Concurrent::AtomicFixnum.new(rand(expire_every).to_i)
          end

          def count(count)
            value = counter.increment(count)
            new_multiple_of_expire_every?(value - count, value)
          end

          private
            def new_multiple_of_expire_every?(first_value, second_value)
              first_value / expire_every != second_value / expire_every
            end
        end
    end
  end
end
