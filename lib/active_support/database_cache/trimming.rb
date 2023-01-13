module ActiveSupport
  module DatabaseCache
    module Trimming
      # If deleting X records, we'll select X * ID_LIMIT_MULTIPLIER and randomly delete X of those
      # The selection doesn't lock so it allows more deletion concurrency
      # We then delete by primary key, which avoids locking on indexes
      #
      # With a concurrent deletions selecting more records and choosing randomly
      # between them should help reduce deletion overlap when that happens
      TRIM_SELECT_MULTIPLIER = 5

      # For every write that we do, we delete DELETION_MULTIPLIER times as many records.
      # This ensures there is downward pressure on the cache size while there is valid data to delete
      TRIM_DELETE_MULTIPLIER = 1.25

      def initialize(options = {})
        super(options)
        @trim_batch_size = options.delete(:trim_batch_size) || 100
        @min_age = options.delete(:min_age) || 2.weeks

        @cache_full = options.delete(:cache_full)
        @cache_full_callable = @cache_full.respond_to?(:call)

        @trim_select_limit = @trim_batch_size * TRIM_SELECT_MULTIPLIER
        @trim_counters = @shards.to_h { |shard| [shard, 0] }
      end

      private
        def trim(write_count)
          async do |shard|
            increment_trim_counter(write_count, shard)
          end
        end

        def increment_trim_counter(count, shard)
          @trim_counters[shard] += count * TRIM_DELETE_MULTIPLIER
          while @trim_counters[shard] > @trim_batch_size
            with_role_and_shard(role: @writing_role, shard: shard) do
              Entry.delete(trimming_id_candidates)
              @trim_counters[shard] -= @trim_batch_size
            end
          end
        end

        def trimming_id_candidates
          relation = Entry.least_recently_used.limit(@trim_select_limit)
          relation = relation.where("updated_at < ?", @min_age.ago) unless cache_full?
          relation.ids.sample(@trim_batch_size)
        end

        def cache_full?
          @cache_full_callable ? @cache_full.call : @cache_full
        end
    end
  end
end
