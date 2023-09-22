require "solid_cache/cluster"

module SolidCache
  class Store < ActiveSupport::Cache::Store
    require "solid_cache/store/operations"

    include Operations

    MAX_KEY_BYTESIZE = 1024
    SQL_WILDCARD_CHARS = [ '_', '%' ]

    DEFAULT_ERROR_HANDLER = -> (method:, returning:, exception:) do
      if logger
        logger.error { "SolidCacheStore: #{method} failed, returned #{returning.inspect}: #{exception.class}: #{exception.message}" }
      end
    end

    def self.supports_cache_versioning?
      true
    end

    prepend ActiveSupport::Cache::Strategy::LocalCache

    attr_reader :max_key_bytesize, :primary_cluster, :clusters

    def initialize(options = {})
      super(options)
      @max_key_bytesize = MAX_KEY_BYTESIZE
      @error_handler = options.fetch(:error_handler, DEFAULT_ERROR_HANDLER)

      clusters_options = options.fetch(:clusters) { [options.fetch(:cluster, {})] }

      @clusters = clusters_options.map.with_index do |cluster_options, index|
        Cluster.new(options.merge(cluster_options).merge(async_writes: index != 0))
      end

      @primary_cluster = clusters.first
    end

    def setup!
      clusters.each(&:setup!)
    end

    def delete_matched(matcher, options = {})
      instrument :delete_matched, matcher do
        raise ArgumentError, "Only strings are supported: #{matcher.inspect}" unless String === matcher
        raise ArgumentError, "Strings cannot start with wildcards" if SQL_WILDCARD_CHARS.include?(matcher[0])

        options ||= {}
        batch_size = options.fetch(:batch_size, 1000)

        matcher = namespace_key(matcher, options)

        delete_matched_entries(matcher, batch_size)
      end
    end

    def increment(name, amount = 1, options = nil)
      options = merged_options(options)
      key = normalize_key(name, options)

      increment_entry(key, amount)
    end

    def decrement(name, amount = 1, options = nil)
      options = merged_options(options)
      key = normalize_key(name, options)

      decrement_entry(key, amount)
    end

    def cleanup(options = nil)
      raise NotImplementedError.new("#{self.class.name} does not support cleanup")
    end

    def clear(options = nil)
      raise NotImplementedError.new("#{self.class.name} does not support clear")
    end

    def stats
      primary_cluster.stats
    end

    private
      def read_entry(key, **options)
        deserialize_entry(read_serialized_entry(key, **options), **options)
      end

      def read_serialized_entry(key, raw: false, **options)
        get_entry(key)
      end

      def write_entry(key, entry, raw: false, **options)
        payload = serialize_entry(entry, raw: raw, **options)
        # No-op for us, but this writes it to the local cache
        write_serialized_entry(key, payload, raw: raw, **options)

        set_entry(key, payload)
      end

      def write_serialized_entry(key, payload, raw: false, unless_exist: false, expires_in: nil, race_condition_ttl: nil, **options)
        true
      end

      def read_serialized_entries(keys)
        get_entries(keys).reduce(&:merge!)
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

          set_entries(serialized_entries).all?
        end
      end

      def delete_entry(key, **options)
        delete_entry_internal(key)
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
