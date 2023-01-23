module SolidCache
  module Trimming
    # For every write that we do, we attempt to delete TRIM_DELETE_MULTIPLIER times as many records.
    # This ensures there is downward pressure on the cache size while there is valid data to delete
    TRIM_DELETE_MULTIPLIER = 1.25

    # If deleting X records, we'll select X * TRIM_SELECT_MULTIPLIER and randomly delete X of those
    # The selection doesn't lock so it allows more deletion concurrency, but some of the selected records
    # might be deleted already. The delete multiplier should compensate for that.
    TRIM_SELECT_MULTIPLIER = 5

    def initialize(options = {})
      super(options)
      @trim_batch_size = options.delete(:trim_batch_size) || 100
      @trim_by = options.delete(:trim_by) || :lru

      raise ArgumentError, ":trim_by must be :lru (default) or :expiry" unless %i[ lru expiry ].include?(@trim_by)

      @max_age = options.delete(:max_age) || 2.weeks

      @cache_full = options.delete(:cache_full)
      @cache_full_callable = @cache_full.respond_to?(:call)
    end

    private
      def trim(write_count)
        async do |shard|
          trim_count(write_count, shard)
        end
      end

      def trim_count(count, shard)
        trim_counters[shard] += count * TRIM_DELETE_MULTIPLIER
        while trim_counters[shard] > @trim_batch_size
          with_role_and_shard(role: @writing_role, shard: shard) do
            trim_batch
            trim_counters[shard] -= @trim_batch_size
          end
        end
      end

      def trim_batch
        if @trim_by == :lru
          trim_batch_by_lru
        else
          trim_batch_by_expiry
        end
      end

      def trim_batch_by_lru(batch_size: @trim_batch_size)
        relation = Entry.least_recently_used
        relation = relation.where("updated_at < ?", @max_age.ago) unless cache_full?

        Entry.delete(trim_candidate_ids(relation, batch_size: batch_size))
      end

      def trim_batch_by_expiry(batch_size: @trim_batch_size)
        relation = Entry.longest_expired
        relation = relation.where("expires_at < ?", Time.now) unless cache_full?

        ids = trim_candidate_ids(relation, batch_size: batch_size)
        Entry.delete(ids)

        # Fall back to LRU if the cache is full and there are not enough expired records available
        shortfall = batch_size - ids.count
        trim_batch_by_lru(batch_size: shortfall) if cache_full? && shortfall > 0
      end

      def trim_candidate_ids(relation, batch_size:)
        relation.limit(batch_size * TRIM_SELECT_MULTIPLIER).ids.sample(batch_size)
      end

      def trim_counters
        @trim_counters ||= shards.to_h { |shard| [shard, 0] }
      end

      def cache_full?
        @cache_full_callable ? @cache_full.call : @cache_full
      end
  end
end
