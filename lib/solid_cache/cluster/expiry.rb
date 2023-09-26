require "concurrent/atomic/atomic_fixnum"

module SolidCache
  class Cluster
    module Expiry
      # For every write that we do, we attempt to delete EXPIRY_MULTIPLIER times as many records.
      # This ensures there is downward pressure on the cache size while there is valid data to delete
      EXPIRY_MULTIPLIER = 1.25

      # If deleting X records, we'll select X * EXPIRY_SELECT_MULTIPLIER and randomly delete X of those
      # The selection doesn't lock so it allows more deletion concurrency, but some of the selected records
      # might be deleted already. The expiry multiplier should compensate for that.
      EXPIRY_SELECT_MULTIPLIER = 3

      attr_reader :expiry_batch_size, :expiry_select_size, :expire_every, :max_age, :max_entries

      def initialize(options = {})
        super(options)
        @expiry_batch_size = options.fetch(:expiry_batch_size, 100)
        @expiry_select_size = expiry_batch_size * EXPIRY_SELECT_MULTIPLIER
        @expire_every = [(expiry_batch_size / EXPIRY_MULTIPLIER).floor, 1].max
        @max_age = options.fetch(:max_age, 2.weeks.to_i)
        @max_entries = options.fetch(:max_entries, nil)
      end

      def track_writes(count)
        expire_later if expiry_counter.count(count)
      end

      private
        def cache_full?
          max_entries && max_entries < Entry.id_range
        end

        def expire_later
          async { expire }
        end

        def expire
          Entry.expire(expiry_candidate_ids)
        end

        def expiry_candidate_ids
          Entry \
            .first_n_id_and_created_at(expiry_select_size)
            .tap { |candidates| candidates.select! { |id, created_at| created_at < max_age.seconds.ago } unless cache_full? }
            .sample(expiry_batch_size)
            .map { |id, created_at| id }
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
