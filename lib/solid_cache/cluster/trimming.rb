require "concurrent/atomic/atomic_fixnum"

module SolidCache
  class Cluster
    module Trimming
      # For every write that we do, we attempt to delete TRIM_DELETE_MULTIPLIER times as many records.
      # This ensures there is downward pressure on the cache size while there is valid data to delete
      TRIM_DELETE_MULTIPLIER = 1.25

      # If deleting X records, we'll select X * TRIM_SELECT_MULTIPLIER and randomly delete X of those
      # The selection doesn't lock so it allows more deletion concurrency, but some of the selected records
      # might be deleted already. The delete multiplier should compensate for that.
      TRIM_SELECT_MULTIPLIER = 3

      attr_reader :trim_batch_size, :trim_every, :max_age, :max_entries

      def initialize(options = {})
        super(options)
        @trim_batch_size = options.fetch(:trim_batch_size, 100)
        @trim_every = [(trim_batch_size * 0.8).floor, 1].max
        @max_age = options.fetch(:max_age, 2.weeks.to_i)
        @max_entries = options.fetch(:max_entries, nil)
      end

      def trim(write_count)
        counter = trim_counters[Entry.current_shard]
        counter.increment(write_count)
        value = counter.value
        if value > trim_every && counter.compare_and_set(value, value - trim_every)
          async { trim_batch }
        end
      end

      private
        def trim_batch
          if (ids = trim_candidates).any?
            Entry.delete_by_ids(ids)
          end
        end

        def trim_counters
          @trim_counters ||= connection_names.to_h { |connection_name| [ connection_name, trim_counter ] }
        end

        def cache_full?
          max_entries && max_entries < Entry.id_range
        end

        def trim_counter
          # Pre-fill the first counter to prevent herding and to account
          # for discarded counters from the last shutdown
          Concurrent::AtomicFixnum.new(rand(trim_every).to_i)
        end

        def trim_select_size
          trim_batch_size * TRIM_SELECT_MULTIPLIER
        end

        def trim_candidates
          cache_full = cache_full?

          Entry \
            .first_n(trim_select_size)
            .pluck(:id, :created_at)
            .filter_map { |id, created_at| id if cache_full || created_at < max_age.seconds.ago }
            .sample(trim_batch_size)
        end
    end
  end
end
