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

      attr_reader :expiry_batch_size, :expire_every, :max_age, :max_entries

      def initialize(options = {})
        super(options)
        @expiry_batch_size = options.fetch(:expiry_batch_size, 100)
        @expire_every = [(expiry_batch_size / EXPIRY_MULTIPLIER).floor, 1].max
        @max_age = options.fetch(:max_age, 2.weeks.to_i)
        @max_entries = options.fetch(:max_entries, nil)
      end

      def expire_later(write_count)
        counter = expiry_counters[Entry.current_shard]
        counter.increment(write_count)
        value = counter.value
        if value > expire_every && counter.compare_and_set(value, value - expire_every)
          async { expire_batch }
        end
      end

      private
        def expire_batch
          if (ids = expiry_candidates).any?
            Entry.delete_by_ids(ids)
          end
        end

        def expiry_counters
          @expiry_counters ||= connection_names.to_h { |connection_name| [ connection_name, expiry_counter ] }
        end

        def cache_full?
          max_entries && max_entries < Entry.id_range
        end

        def expiry_counter
          # Pre-fill the first counter to prevent herding and to account
          # for discarded counters from the last shutdown
          Concurrent::AtomicFixnum.new(rand(expire_every).to_i)
        end

        def expiry_select_size
          expiry_batch_size * EXPIRY_SELECT_MULTIPLIER
        end

        def expiry_candidates
          cache_full = cache_full?

          Entry \
            .first_n(expiry_select_size)
            .pluck(:id, :created_at)
            .filter_map { |id, created_at| id if cache_full || created_at < max_age.seconds.ago }
            .sample(expiry_batch_size)
        end
    end
  end
end
