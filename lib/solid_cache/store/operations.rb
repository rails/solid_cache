module SolidCache
  class Store
    module Operations
      private
        def delete_matched_entries(matcher, batch_size)
          writing_all(failsafe: :delete_matched) do
            Entry.delete_matched(matcher, batch_size: batch_size)
          end
        end

        def increment_entry(key, amount)
          writing_key(key, failsafe: :increment) do
            Entry.increment(key, amount)
          end
        end

        def decrement_entry(key, amount)
          writing_key(key, failsafe: :decrement) do
            Entry.increment(key, -amount)
          end
        end

        def get_entry(key)
          reading_key(key, failsafe: :read_entry) do
            Entry.get(key)
          end
        end

        def get_entries(keys)
          reading_keys(keys, failsafe: :read_multi_mget, failsafe_returning: {}) do |keys|
            Entry.get_all(keys)
          end
        end

        def set_entry(key, payload)
          writing_key(key, failsafe: :write_entry, failsafe_returning: false) do |cluster|
            Entry.set(key, payload)
            cluster.trim(1)
            true
          end
        end

        def set_entries(entries)
          writing_keys(entries, failsafe: :write_multi_entries, failsafe_returning: false) do |cluster, shard, entries|
            Entry.set_all(entries)
            cluster.trim(entries.count)
            true
          end
        end

        def delete_entry_internal(key)
          writing_key(key, failsafe: :delete_entry, failsafe_returning: false) do
            Entry.delete_by_key(key)
          end
        end
    end
  end
end
