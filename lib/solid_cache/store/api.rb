# frozen_string_literal: true

module SolidCache
  class Store
    module Api
      DEFAULT_MAX_KEY_BYTESIZE = 1024
      SQL_WILDCARD_CHARS = [ "_", "%" ]

      attr_reader :max_key_bytesize

      def initialize(options = {})
        super(options)

        @max_key_bytesize = options.fetch(:max_key_bytesize, DEFAULT_MAX_KEY_BYTESIZE)
      end

      def delete_matched(matcher, options = {})
        instrument :delete_matched, matcher do
          raise ArgumentError, "Only strings are supported: #{matcher.inspect}" unless String === matcher
          raise ArgumentError, "Strings cannot start with wildcards" if SQL_WILDCARD_CHARS.include?(matcher[0])

          options ||= {}
          batch_size = options.fetch(:batch_size, 1000)

          matcher = namespace_key(matcher, options)

          entry_delete_matched(matcher, batch_size)
        end
      end

      def increment(name, amount = 1, options = nil)
        options = merged_options(options)
        key = normalize_key(name, options)

        entry_increment(key, amount)
      end

      def decrement(name, amount = 1, options = nil)
        options = merged_options(options)
        key = normalize_key(name, options)

        entry_decrement(key, amount)
      end

      def cleanup(options = nil)
        raise NotImplementedError.new("#{self.class.name} does not support cleanup")
      end

      def clear(options = nil)
        entry_clear
      end

      private
        def read_entry(key, **options)
          deserialize_entry(read_serialized_entry(key, **options), **options)
        end

        def read_serialized_entry(key, raw: false, **options)
          entry_read(key)
        end

        def write_entry(key, entry, raw: false, **options)
          payload = serialize_entry(entry, raw: raw, **options)
          # No-op for us, but this writes it to the local cache
          write_serialized_entry(key, payload, raw: raw, **options)

          entry_write(key, payload)
        end

        def write_serialized_entry(key, payload, raw: false, unless_exist: false, expires_in: nil, race_condition_ttl: nil, **options)
          true
        end

        def read_serialized_entries(keys)
          entry_read_multi(keys).reduce(&:merge!)
        end

        def read_multi_entries(names, **options)
          keys_and_names = names.index_by { |name| normalize_key(name, options) }
          serialized_entries = read_serialized_entries(keys_and_names.keys)

          keys_and_names.each_with_object({}) do |(key, name), results|
            serialized_entry = serialized_entries[key]
            entry = deserialize_entry(serialized_entry, **options)

            next unless entry

            version = normalize_version(name, options)

            if entry.expired?
              delete_entry(key, **options)
            elsif !entry.mismatched?(version)
              if defined? ActiveSupport::Cache::DeserializationError
                begin
                  results[name] = entry.value
                rescue ActiveSupport::Cache::DeserializationError
                end
              else
                results[name] = entry.value
              end
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

            entry_write_multi(serialized_entries).all?
          end
        end

        def delete_entry(key, **options)
          entry_delete(key)
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
            ActiveSupport::Cache::Entry.new(payload)
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
