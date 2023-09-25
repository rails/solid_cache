module SolidCache
  class Store
    module Entries
      private
        def entry_delete_matched(matcher, batch_size)
          writing_all(failsafe: :delete_matched) do
            SolidCache::Entry.delete_matched(matcher, batch_size: batch_size)
          end
        end

        def entry_clear
          writing_all(failsafe: :clear) do
            SolidCache::Entry.clear
          end
        end

        def entry_increment(key, amount)
          writing_key(key, failsafe: :increment) do
            SolidCache::Entry.increment(key, amount)
          end
        end

        def entry_decrement(key, amount)
          writing_key(key, failsafe: :decrement) do
            SolidCache::Entry.decrement(key, amount)
          end
        end

        def entry_read(key)
          reading_key(key, failsafe: :read_entry) do
            SolidCache::Entry.read(key)
          end
        end

        def entry_read_multi(keys)
          reading_keys(keys, failsafe: :read_multi_mget, failsafe_returning: {}) do |keys|
            SolidCache::Entry.read_multi(keys)
          end
        end

        def entry_write(key, payload)
          writing_key(key, failsafe: :write_entry, failsafe_returning: false) do |cluster|
            SolidCache::Entry.write(key, payload)
            cluster.trim(1)
            true
          end
        end

        def entry_write_multi(entries)
          writing_keys(entries, failsafe: :write_multi_entries, failsafe_returning: false) do |cluster, entries|
            SolidCache::Entry.write_multi(entries)
            cluster.trim(entries.count)
            true
          end
        end

        def entry_delete(key)
          writing_key(key, failsafe: :delete_entry, failsafe_returning: false) do
            SolidCache::Entry.delete_by_key(key)
          end
        end
    end
  end
end
