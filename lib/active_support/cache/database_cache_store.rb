module ActiveSupport
  module Cache
    class DatabaseCacheStore < Store
      def self.supports_cache_versioning?
        true
      end

      prepend Strategy::LocalCache

      def increment(name, amount = 1, options = nil)
        options = merged_options(options)
        key = normalize_key(name, options)
        DatabaseCache::Entry.increment(key, amount)
      end

      def decrement(name, amount = 1, options = nil)
        options = merged_options(options)
        key = normalize_key(name, options)
        DatabaseCache::Entry.increment(key, -amount)
      end

      def cleanup(options = nil)
        raise NotImplementedError.new("#{self.class.name} does not support cleanup")
      end

      def clear(options = nil)
        raise NotImplementedError.new("#{self.class.name} does not support clear")
      end

      private
        def read_entry(key, **options)
          deserialize_entry(read_serialized_entry(key, **options), **options)
        end

        def read_serialized_entry(key, raw: false, **options)
          DatabaseCache::Entry.get(key)
        end

        def write_entry(key, entry, raw: false, **options)
          write_serialized_entry(key, serialize_entry(entry, raw: raw, **options), raw: raw, **options)
        end

        def write_serialized_entry(key, payload, raw: false, unless_exist: false, expires_in: nil, race_condition_ttl: nil, **options)
          DatabaseCache::Entry.set(key, payload)
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

        def serialize_entry(entry, raw: false, **options)
          if raw
            entry.value.to_s
          else
            super(entry, raw: raw, **options)
          end
        end

        def deserialize_entry(payload, raw: false, **)
          if payload && raw
            Entry.new(payload)
          else
            super(payload)
          end
        end
    end
  end
end
