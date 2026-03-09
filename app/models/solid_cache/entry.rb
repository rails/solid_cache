# frozen_string_literal: true

module SolidCache
  class Entry < Record
    include Encryption, Expiration, Size

    # The estimated cost of an extra row in bytes, including fixed size columns, overhead, indexes and free space
    # Based on experimentation on SQLite, MySQL and Postgresql.
    # A bit high for SQLite (more like 90 bytes), but about right for MySQL/Postgresql.
    ESTIMATED_ROW_OVERHEAD = 140

    # Assuming MessagePack serialization
    ESTIMATED_ENCRYPTION_OVERHEAD = 170

    KEY_HASH_ID_RANGE = -(2**63)..(2**63 - 1)

    MULTI_BATCH_SIZE = 1000

    class << self
      def write(key, value)
        write_multi([ { key: key, value: value } ])
      end

      def write_multi(payloads)
        without_query_cache do
          payloads.each_slice(MULTI_BATCH_SIZE).each do |payload_batch|
            upsert_all \
              add_key_hash_and_byte_size(payload_batch),
              unique_by: upsert_unique_by, on_duplicate: :update, update_only: [ :key, :value, :byte_size ]
          end
        end
      end

      def read(key)
        read_multi([key])[key]
      end

      def read_multi(keys)
        without_query_cache do
          {}.tap do |results|
            keys.each_slice(MULTI_BATCH_SIZE).each do |keys_batch|
              query = Arel.sql(select_sql(keys_batch), *key_hashes_for(keys_batch))

              with_connection do |connection|
                results.merge!(connection.select_all(query, "SolidCache::Entry Load").cast_values(attribute_types).to_h)
              end
            end
          end
        end
      end

      def delete_by_key(*keys)
        without_query_cache do
          where(key_hash: key_hashes_for(keys)).delete_all
        end
      end

      def clear_truncate
        with_connection do |connection|
          connection.truncate(table_name)
        end
      end

      def clear_delete
        without_query_cache do
          in_batches.delete_all
        end
      end

      def lock_and_write(key, placeholder_payload: nil, &block)
        transaction do
          without_query_cache do
            ensure_lockable_row_exists(key, placeholder_payload) if placeholder_payload

            result = lock.where(key_hash: key_hash_for(key)).pick(:key, :value)
            current_value = result&.first == key ? result[1] : nil
            new_value = block.call(current_value)

            if new_value
              write(key, new_value)
            elsif placeholder_payload && current_value == placeholder_payload
              delete_by_key(key)
            end

            new_value
          end
        end
      end

      def id_range
        without_query_cache do
          pick(Arel.sql("max(id) - min(id) + 1")) || 0
        end
      end

      private
        def ensure_lockable_row_exists(key, payload)
          retries = 0

          begin
            insert_all(
              add_key_hash_and_byte_size([
                { key: key, value: payload, created_at: Time.current }
              ]),
              unique_by: upsert_unique_by
            )
          rescue ActiveRecord::RecordNotUnique
            # Another concurrent writer created the row first.
          rescue ActiveRecord::StatementInvalid => error
            raise unless sqlite_busy_exception?(error) && retries < 3

            retries += 1
            sleep(0.01 * retries)
            retry
          end
        end

        def sqlite_busy_exception?(error)
          connection.adapter_name == "SQLite" && error.message.include?("database is locked")
        end

        def add_key_hash_and_byte_size(payloads)
          payloads.map do |payload|
            payload.dup.tap do |payload|
              payload[:key_hash] = key_hash_for(payload[:key])
              payload[:byte_size] = byte_size_for(payload)
            end
          end
        end

        def upsert_unique_by
          with_connection do |connection|
            connection.supports_insert_conflict_target? ? :key_hash : nil
          end
        end

        # This constructs and caches a SQL query for a given number of keys.
        #
        # The query is constructed with two bind parameters to generate an IN (...) condition,
        # which is then replaced with the correct amount based on the number of keys. The
        # parameters are filled later when executing the query. This is done through Active Record
        # to ensure the field and table names are properly quoted and escaped based on the used database adapter.

        # For example: The query for 4 keys will be transformed from:
        # > SELECT "key", "value" FROM "solid_cache_entries" WHERE "key_hash" IN (1111, 2222)
        # into:
        # > SELECT "key", "value" FROM "solid_cache_entries" WHERE "key_hash" IN (?, ?, ?, ?)
        def select_sql(keys)
          @select_sql ||= {}
          @select_sql[keys.count] ||= \
            where(key_hash: [ 1111, 2222 ])
              .select(:key, :value)
              .to_sql
              .gsub("1111, 2222", Array.new(keys.count, "?").join(", "))
        end

        def key_hash_for(key)
          # Need to unpack this as a signed integer - Postgresql and SQLite don't support unsigned integers
          Digest::SHA256.digest(key.to_s).unpack("q>").first
        end

        def key_hashes_for(keys)
          keys.map { |key| key_hash_for(key) }
        end

        def byte_size_for(payload)
          payload[:key].to_s.bytesize + payload[:value].to_s.bytesize + estimated_row_overhead
        end

        def estimated_row_overhead
          if SolidCache.configuration.encrypt?
            ESTIMATED_ROW_OVERHEAD + ESTIMATED_ENCRYPTION_OVERHEAD
          else
            ESTIMATED_ROW_OVERHEAD
          end
        end

        def without_query_cache(&block)
          uncached(dirties: false, &block)
        end
    end
  end
end

ActiveSupport.run_load_hooks :solid_cache_entry, SolidCache::Entry
