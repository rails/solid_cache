require "active_support/database_cache/connection_handling"
require "active_support/database_cache/async_execution"
require "active_support/database_cache/touching"
require "active_support/database_cache/trimming"

module ActiveSupport
  module DatabaseCache
    class Store < ActiveSupport::Cache::Store
      include ConnectionHandling, AsyncExecution
      include Touching, Trimming

      MAX_KEY_BYTESIZE = 1024
      SQL_WILDCARD_CHARS = [ '_', '%' ]

      def self.supports_cache_versioning?
        true
      end

      prepend Cache::Strategy::LocalCache

      attr_reader :max_key_bytesize

      def initialize(options = {})
        super(options)
        @max_key_bytesize = MAX_KEY_BYTESIZE
      end

      def delete_matched(matcher, options = {})
        instrument :delete_matched, matcher do
          raise ArgumentError, "Only strings are supported: #{matcher.inspect}" unless String === matcher
          raise ArgumentError, "Strings cannot start with wildcards" if SQL_WILDCARD_CHARS.include?(matcher[0])

          options ||= {}
          batch_size = options.fetch(:batch_size, 1000)

          matcher = namespace_key(matcher, options)

          writing_all_shards { Entry.delete_matched(matcher, batch_size: batch_size) }
        end
      end

      def increment(name, amount = 1, options = nil)
        options = merged_options(options)
        key = normalize_key(name, options)
        writing_shard(normalized_key: key) { Entry.increment(key, amount) }
      end

      def decrement(name, amount = 1, options = nil)
        options = merged_options(options)
        key = normalize_key(name, options)
        writing_shard(normalized_key: key) { Entry.increment(key, -amount) }
      end

      def cleanup(options = nil)
        raise NotImplementedError.new("#{self.class.name} does not support cleanup")
      end

      def clear(options = nil)
        raise NotImplementedError.new("#{self.class.name} does not support clear")
      end

      def shard_for_key(key, options = nil)
        shard_for_normalized_key(normalize_key(key, merged_options(options)))
      end

      private
        def read_entry(key, **options)
          deserialize_entry(read_serialized_entry(key, **options), **options)
        end

        def read_serialized_entry(key, raw: false, **options)
          reading_shard(normalized_key: key) do
            id, serialized_entry = Entry.get(key)
            touch([id]) if id
            serialized_entry
          end
        end

        def write_entry(key, entry, raw: false, **options)
          # This writes it to the cache
          payload = serialize_entry(entry, raw: raw, **options)
          write_serialized_entry(key, payload, raw: raw, **options)

          writing_shard(normalized_key: key) do
            Entry.set(key, payload)
            trim(1)
          end
        end

        def write_serialized_entry(key, payload, raw: false, unless_exist: false, expires_in: nil, race_condition_ttl: nil, **options)
          true
        end

        def read_serialized_entries(keys)
          serialize_entries = {}
          reading_across_shards(list: keys) do |keys|
            rows = Entry.get_all(keys)
            ids = []
            rows.each do |(key, id, value)|
              ids << id
              serialize_entries[key] = value
            end
            touch(ids)
          end
          serialize_entries
        end

        def read_multi_entries(names, **options)
          keys_and_names = names.to_h { |name| [normalize_key(name, options), name] }
          serialized_entries = read_serialized_entries(keys_and_names.keys)

          keys_and_names.each_with_object({}) do |(key, name), results|
            serialized_entry = serialized_entries[key]
            entry = deserialize_entry(serialized_entry, **options)

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

            writing_across_shards(list: serialized_entries) do |serialized_entries|
              Entry.set_all(serialized_entries)
              trim(serialized_entries.count)
            end
          end
        end

        def delete_entry(key, **options)
          writing_shard(normalized_key: key) { Entry.delete_by_key(key) }
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
            Cache::Entry.new(payload)
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
    end
  end
end
