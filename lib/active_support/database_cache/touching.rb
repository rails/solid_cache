module ActiveSupport
  module DatabaseCache
    module Touching
      def initialize(options)
        super(options)
        @touch_batch_size = options.delete(:touch_batch_size) || 100
      end

      private
        def touch(ids)
          async do |shard|
            touch_add_ids(ids, shard)
          end
        end

        def touch_add_ids(ids, shard)
          touch_ids[shard].concat(ids)
          while touch_ids[shard].size > @touch_batch_size
            with_role_and_shard(role: @writing_role, shard: shard) do
              Entry.touch_by_ids(touch_ids[shard].shift(@touch_batch_size).uniq)
            end
          end
        end

        def touch_ids
          @touch_ids ||= shards.to_h { |shard| [shard, []] }
        end
    end
  end
end
