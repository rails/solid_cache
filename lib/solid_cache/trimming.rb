module SolidCache
  module Trimming
    # For every write that we do, we attempt to delete TRIM_DELETE_MULTIPLIER times as many records.
    # This ensures there is downward pressure on the cache size while there is valid data to delete
    TRIM_DELETE_MULTIPLIER = 1.25

    # If deleting X records, we'll select X * TRIM_SELECT_MULTIPLIER and randomly delete X of those
    # The selection doesn't lock so it allows more deletion concurrency, but some of the selected records
    # might be deleted already. The delete multiplier should compensate for that.
    TRIM_SELECT_MULTIPLIER = 3

    attr_reader :trim_batch_size, :max_age, :max_entries

    def initialize(options = {})
      super(options)
      @trim_batch_size = options.delete(:trim_batch_size) || 100
      @max_age = options.delete(:max_age) || 2.weeks.to_i
      @max_entries = options.delete(:max_entries)
    end

    private
      def trim(write_count)
        async do |shard|
          trim_count(write_count, shard)
        end
      end

      def trim_count(count, shard)
        trim_counters[shard] += count * TRIM_DELETE_MULTIPLIER
        while trim_counters[shard] > trim_batch_size
          with_role_and_shard(role: writing_role, shard: shard) do
            trim_batch
            trim_counters[shard] -= trim_batch_size
          end
        end
      end

      def trim_batch
        candidates = Entry.order(:id).limit(trim_batch_size * TRIM_SELECT_MULTIPLIER).select(:id, :created_at).to_a
        candidates.select! { |entry| entry.created_at < max_age.seconds.ago } unless cache_full?
        candidates = candidates.sample(trim_batch_size)

        Entry.delete(candidates.map(&:id)) if candidates.any?
      rescue => e
        debugger
      end

      def trim_counters
        # Pre-fill the first counter to prevent herding and to account
        # for discarded counters from the last shutdown
        @trim_counters ||= shards.to_h { |shard| [shard, rand(trim_batch_size)] }
      end

      def cache_full?
        max_entries && max_entries < Entry.id_range
      end
  end
end
