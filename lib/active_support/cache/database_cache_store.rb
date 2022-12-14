module ActiveSupport
  module Cache
    class DatabaseCacheStore < Store
      MAX_KEY_BYTESIZE = 1024
      SQL_WILDCARD_CHARS = [ '_', '%' ]

      def self.supports_cache_versioning?
        true
      end

      prepend Strategy::LocalCache

      attr_reader :reading_role, :writing_role, :max_key_bytesize

      def initialize(options)
        @writing_role = options[:writing_role] || options[:role]
        @reading_role = options[:reading_role] || options[:role]
        @max_key_bytesize = MAX_KEY_BYTESIZE
        super(options)
      end

      def delete_matched(matcher, options = {})
        instrument :delete_matched, matcher do
          raise ArgumentError, "Only strings are supported: #{matcher.inspect}" unless String === matcher
          raise ArgumentError, "Strings cannot start with wildcards" if SQL_WILDCARD_CHARS.include?(matcher[0])

          options ||= {}
          batch_size = options.fetch(:batch_size, 1000)

          matcher = namespace_key(matcher, options)

          with_writing_role { DatabaseCache::Entry.delete_matched(matcher, batch_size: batch_size) }
        end
      end

      def increment(name, amount = 1, options = nil)
        options = merged_options(options)
        key = normalize_key(name, options)
        with_writing_role { DatabaseCache::Entry.increment(key, amount) }
      end

      def decrement(name, amount = 1, options = nil)
        options = merged_options(options)
        key = normalize_key(name, options)
        with_writing_role { DatabaseCache::Entry.increment(key, -amount) }
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
          with_reading_role { DatabaseCache::Entry.get(key) }
        end

        def write_entry(key, entry, raw: false, **options)
          # This writes it to the cache
          payload = serialize_entry(entry, raw: raw, **options)
          write_serialized_entry(key, payload, raw: raw, **options)
          with_writing_role { DatabaseCache::Entry.set(key, payload) }
        end

        def write_serialized_entry(key, payload, raw: false, unless_exist: false, expires_in: nil, race_condition_ttl: nil, **options)
          true
        end

        def read_multi_entries(names, **options)
          keys_and_names = names.to_h { |name| [normalize_key(name, options), name] }
          serialized_entries = with_reading_role { DatabaseCache::Entry.get_all(keys_and_names.keys) }
          keys_and_names.each_with_object({}) do |(key, name), results|
            entry = deserialize_entry(serialized_entries[key], **options)

            next unless entry

            version = normalize_version(name, options)

            if entry.expired?
              delete_entry(key, **options)
            elsif !entry.mismatched?(version)
              results[name] = entry.value
            end
          end
        end

        def write_multi_entries(entries, expires_in: nil, **options)
          if entries.any?
            serialized_entries = serialize_entries(entries, **options)
            # to add them to the local cache
            serialized_entries.each do |entries|
              write_serialized_entry(entries[:key], entries[:value])
            end
            with_writing_role { DatabaseCache::Entry.set_all(serialized_entries) }
          end
        end

        def delete_entry(key, **options)
          with_writing_role { DatabaseCache::Entry.delete(key) }
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

        def serialize_entries(entries, **options)
          entries.map do |key, entry|
            { key: key, value: serialize_entry(entry, **options) }
          end
        end

        def deserialize_entry(payload, raw: false, **)
          if payload && raw
            Entry.new(payload)
          else
            super(payload)
          end
        end

        def normalize_key(key, options)
          truncate_key super&.b
        end

        def truncate_key(key)
          if key && key.bytesize > max_key_bytesize
            suffix = ":hash:#{ActiveSupport::Digest.hexdigest(key)}"
            truncate_at = max_key_bytesize - suffix.bytesize
            "#{key.byteslice(0, truncate_at)}#{suffix}".b
          else
            key
          end
        end

        def with_writing_role
          with_role(writing_role) { yield }
        end

        def with_reading_role
          with_role(reading_role) { yield }
        end

        def with_role(role)
          if role
            DatabaseCache::ApplicationRecord.connected_to(role: role) { yield }
          else
            yield
          end
        end
    end
  end
end
