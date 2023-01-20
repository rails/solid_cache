module SolidCache
  class Entry < Record
    scope :least_recently_used, -> { order(:updated_at) }

    class << self
      def set(key, value, expires_at: nil)
        upsert_all([{key: key, value: value, expires_at: expires_at}], unique_by: upsert_unique_by, update_only: [:value, :expires_at])
      end

      def set_all(payloads, expires_at: nil)
        upsert_all(payloads, unique_by: upsert_unique_by, update_only: [:value, :expires_at])
      end

      def get(key)
        where(key: key).skip_query_cache!.pick(:id, :value)
      end

      def get_all(keys)
        where(key: keys).skip_query_cache!.pluck(:key, :id, :value)
      end

      def delete_by_key(key)
        where(key: key).delete_all.nonzero?
      end

      def delete_matched(matcher, batch_size:)
        like_matcher = arel_table[:key].matches(matcher, nil, true)
        where(like_matcher).select(:id).find_in_batches(batch_size: batch_size) do |entries|
          delete_by(id: entries.map(&:id))
        end
      end

      def increment(key, amount)
        transaction do
          amount += lock.where(key: key).pick(:value).to_i
          set(key, amount)
          amount
        end
      end

      def touch_by_ids(ids)
        where(id: ids).touch_all
      end

      private
        def upsert_unique_by
          connection.supports_insert_conflict_target? ? :key : nil
        end
    end
  end
end

ActiveSupport.run_load_hooks :solid_cache_entry, SolidCache::Entry

