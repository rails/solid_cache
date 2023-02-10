module SolidCache
  module Stats
    def stats
      stats = {
        shards: shards.count,
        shards_stats: shards_stats
      }

    end

    private
      def shards_stats
        writing_all_shards.to_h { |shard| [Entry.current_shard, shard_stats] }
      end

      def shard_stats
        oldest_created_at = SolidCache::Entry.order(:id).pick(:created_at)

        {
          max_age: max_age,
          oldest_age: oldest_created_at ? Time.now - oldest_created_at : nil,
          max_entries: max_entries,
          entries: SolidCache::Entry.id_range
        }
      end
  end
end
