module ActiveSupport
  module Cache
    class DatabaseCacheStore < Store
      def increment(name, amount = 1, options = nil)
        raise NotImplementedError.new("#{self.class.name} does not support increment")
      end

      def decrement(name, amount = 1, options = nil)
        raise NotImplementedError.new("#{self.class.name} does not support decrement")
      end

      def cleanup(options = nil)
        raise NotImplementedError.new("#{self.class.name} does not support cleanup")
      end

      def clear(options = nil)
        raise NotImplementedError.new("#{self.class.name} does not support clear")
      end

      private
        def read_entry(key, **options)
          deserialize_entry(DatabaseCache::Entry.get(key))
        end

        def write_entry(key, entry, **options)
          DatabaseCache::Entry.set(key, serialize_entry(entry))
        end

        def read_multi_entries(names, **options)
          names.each_with_object({}) do |name, results|
            key   = normalize_key(name, options)
            entry = read_entry(key, **options)

            next unless entry

            version = normalize_version(name, options)

            if entry.expired?
              delete_entry(key, **options)
            elsif !entry.mismatched?(version)
              results[name] = entry.value
            end
          end
        end

        def write_multi_entries(hash, **options)
          hash.each do |key, entry|
            write_entry key, entry, **options
          end
        end

        def delete_entry(key, **options)
          DatabaseCache::Entry.delete(key)
        end

        def delete_multi_entries(entries, **options)
          entries.count { |key| delete_entry(key, **options) }
        end

    end
  end
end
