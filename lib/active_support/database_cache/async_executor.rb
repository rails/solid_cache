module ActiveSupport
  module DatabaseCache
    class AsyncExecutor
      def initialize(touch_batch_size:, trim_batch_size:, min_age:, cache_full:)
        @executor = Concurrent::SingleThreadExecutor.new(max_queue: 100, fallback_policy: :discard)
        @toucher = Toucher.new(touch_batch_size)
        @trimmer = Trimmer.new(trim_batch_size, min_age, cache_full)
      end

      def touch(ids)
        execute_on_thread do
          @toucher.add_ids(ids)
        end
      end

      def trim(write_count)
        execute_on_thread do
          @trimmer.increment_write_counter(write_count)
        end
      end

      private
        def execute_on_thread(&block)
          @executor << block
        end

      class Toucher
        def initialize(batch_size)
          @batch_size = batch_size
          @ids = []
        end

        def add_ids(ids)
          @ids.concat(ids)
          while @ids.size > @batch_size
            Entry.touch_by_ids(@ids.shift(@batch_size).uniq)
          end
        end
      end

      class Trimmer
        # If deleting X records, we'll select X * ID_LIMIT_MULTIPLIER and randomly delete X of those
        # The selection doesn't lock so it allows more deletion concurrency
        # We then delete by primary key, which avoids locking on indexes
        #
        # With a concurrent deletions selecting more records and choosing randomly
        # between them should help reduce deletion overlap when that happens
        ID_LIMIT_MULTIPLIER = 5

        # For every write that we do, we delete DELETION_MULTIPLIER times as many records.
        # This ensures there is downward pressure on the cache size while there is valid data to delete
        DELETION_MULTIPLIER = 1.25

        def initialize(batch_size, min_age, cache_full)
          @batch_size = batch_size
          @select_limit = batch_size * ID_LIMIT_MULTIPLIER
          @min_age = min_age
          @cache_full = cache_full
          @cache_full_callable = cache_full.respond_to?(:call)
          @delete_counter = 0
        end

        def increment_write_counter(count)
          @delete_counter += count * DELETION_MULTIPLIER
          while @delete_counter > @batch_size
            Entry.delete(deletion_id_sample)
            @delete_counter -= @batch_size
          end
        end

        private
          def deletion_id_sample
            relation = Entry.least_recently_used.limit(@select_limit)
            relation = relation.where("updated_at < ?", @min_age.ago) unless cache_full?
            relation.ids.sample(@batch_size)
          end

          def cache_full?
            @cache_full_callable ? @cache_full.call : @cache_full
          end
      end
    end
  end
end
