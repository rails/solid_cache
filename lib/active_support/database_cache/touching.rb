module ActiveSupport
  module DatabaseCache
    module Touching
      def initialize(options)
        super(options)
        @touch_batch_size = options.fetch(:touch_batch_size, 100)
        @touch_ids = @shards.to_h { |shard| [shard, []] }
      end

      private
        def touch(ids)
          async do
            touch_add_ids(ids, Entry.current_shard)
          end
        end

        def touch_add_ids(ids, shard)
          @touch_ids[shard].concat(ids)
          while @touch_ids[shard].size > @touch_batch_size
            Entry.touch_by_ids(@touch_ids[shard].shift(@touch_batch_size).uniq)
          end
        end
    end
  end
end
