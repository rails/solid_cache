module ActiveSupport
  module DatabaseCache
    class AsyncExecutor
      def initialize(touch_batch_size: 100)
        @touch_batch_size = touch_batch_size

        @executor = Concurrent::SingleThreadExecutor.new(max_queue: 100, fallback_policy: :discard)
        @toucher = Toucher.new(touch_batch_size)
      end

      def touch(ids)
        execute_on_thread do
          @toucher.add_ids(ids)
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
    end
  end
end
