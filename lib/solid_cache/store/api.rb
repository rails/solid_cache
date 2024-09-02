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

      def increment(name, amount = 1, options = nil)
        options = merged_options(options)
        key = normalize_key(name, options)

        instrument :increment, key, amount: amount do
          adjust(name, amount, options)
        end
      end

      def decrement(name, amount = 1, options = nil)
        options = merged_options(options)
        key = normalize_key(name, options)

        instrument :decrement, key, amount: amount do
          adjust(name, -amount, options)
        end
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

        def read_serialized_entry(key, **options)
          entry_read(key)
        end

        def write_entry(key, entry, raw: false, unless_exist: false, **options)
          payload = serialize_entry(entry, raw: raw, **options)

          if unless_exist
            written = false
            entry_lock_and_write(key) do |value|
              if value.nil? || deserialize_entry(value, **options).expired?
                written = true
                payload
              end
            end
          else
            written = entry_write(key, payload)
          end

          write_serialized_entry(key, payload, raw: raw, returning: written, **options)
          written
        end

        def write_serialized_entry(key, payload, raw: false, unless_exist: false, expires_in: nil, race_condition_ttl: nil, returning: true, **options)
          returning
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
          entry_delete_multi(entries).compact.sum
        end

        def serialize_entry(entry, raw: false, **options)
          super(entry, raw: raw, **options)
        end

        def serialize_entries(entries, **options)
          entries.map do |key, entry|
            { key: key, value: serialize_entry(entry, **options) }
          end
        end

        def deserialize_entry(payload, **)
          super(payload)
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

        def adjust(name, amount, options)
          options = merged_options(options)
          key = normalize_key(name, options)

          new_value = entry_lock_and_write(key) do |value|
            serialize_entry(adjusted_entry(value, amount, options))
          end
          deserialize_entry(new_value, **options).value if new_value
        end

        def adjusted_entry(value, amount, options)
          entry = deserialize_entry(value, **options)

          if entry && !entry.expired?
            ActiveSupport::Cache::Entry.new \
              amount + entry.value.to_i, **options.dup.merge(expires_in: nil, expires_at: entry.expires_at)
          elsif /\A\d+\z/.match?(value)
            # This is to match old raw values
            ActiveSupport::Cache::Entry.new(amount + value.to_i, **options)
          else
            ActiveSupport::Cache::Entry.new(amount, **options)
          end
        end
    end
  end
end
