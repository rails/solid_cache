# frozen_string_literal: true

module SolidCache
  class Entry < Record
    include Expiration, Size

    # The estimated cost of an extra row in bytes, including fixed size columns, overhead, indexes and free space
    # Based on experimentation on SQLite, MySQL and Postgresql.
    # A bit high for SQLite (more like 90 bytes), but about right for MySQL/Postgresql.
    ESTIMATED_ROW_OVERHEAD = 140
    KEY_HASH_ID_RANGE = -(2**63)..(2**63 - 1)

    class << self
      def write(key, value)
        upsert_all_no_query_cache([ { key: key, value: value } ])
      end

      def write_multi(payloads)
        upsert_all_no_query_cache(payloads)
      end

      def read(key)
        result = select_all_no_query_cache([key]).first
        result[1] if result&.first == key
      end

      def read_multi(keys)
        results = select_all_no_query_cache(keys).to_h
        results.except!(results.keys - keys)
      end

      def delete_by_key(key)
        delete_no_query_cache(:key_hash, key_hash_for(key)) > 0
      end

      def delete_multi(keys)
        serialized_keys = keys.map { |key| key_hash_for(key) }
        delete_no_query_cache(:key_hash, serialized_keys)
      end

      def clear_truncate
        connection.truncate(table_name)
      end

      def clear_delete
        in_batches.delete_all
      end

      def lock_and_write(key, &block)
        transaction do
          uncached do
            result = lock.where(key_hash: key_hash_for(key)).pick(:key, :value)
            new_value = block.call(result&.first == key ? result[1] : nil)
            write(key, new_value) if new_value
            new_value
          end
        end
      end

      def id_range
        uncached do
          pick(Arel.sql("max(id) - min(id) + 1")) || 0
        end
      end

      private
        def upsert_all_no_query_cache(payloads)
          args = [ self.all,
                   connection_for_insert_all,
                   add_key_hash_and_byte_size(payloads) ].compact
          options = { unique_by: upsert_unique_by,
                      on_duplicate: :update,
                      update_only: upsert_update_only }
          insert_all = ActiveRecord::InsertAll.new(*args, **options)
          sql = connection.build_insert_sql(ActiveRecord::InsertAll::Builder.new(insert_all))

          message = +"#{self} "
          message << "Bulk " if payloads.many?
          message << "Upsert"
          # exec_query_method does not clear the query cache, exec_insert_all does
          connection.send exec_query_method, sql, message
        end

        def connection_for_insert_all
          Rails.version >= "7.2" ? connection : nil
        end

        def add_key_hash_and_byte_size(payloads)
          payloads.map do |payload|
            payload.dup.tap do |payload|
              payload[:key_hash] = key_hash_for(payload[:key])
              payload[:byte_size] = byte_size_for(payload)
            end
          end
        end

        def exec_query_method
          connection.respond_to?(:internal_exec_query) ? :internal_exec_query : :exec_query
        end

        def upsert_unique_by
          connection.supports_insert_conflict_target? ? :key_hash : nil
        end

        def upsert_update_only
          [ :key, :value, :byte_size ]
        end

        def select_all_no_query_cache(keys)
          uncached do
            find_by_sql([select_sql(keys), *key_hashes_for(keys)]).pluck(:key, :value)
          end
        end

        def select_sql(keys)
          @get_sql ||= {}
          @get_sql[keys.count] ||= \
            where(key_hash: [ "1111", "2222" ])
              .select(:key, :value)
              .to_sql
              .gsub("1111, 2222", (["?"] * keys.count).join(", "))
        end

        def delete_no_query_cache(attribute, values)
          uncached do
            relation = where(attribute => values)
            sql = connection.to_sql(relation.arel.compile_delete(relation.table[primary_key]))

            # exec_delete does not clear the query cache
            if connection.prepared_statements?
              connection.exec_delete(sql, "#{name} Delete All", Array(values))
            else
              connection.exec_delete(sql, "#{name} Delete All")
            end
          end
        end

        def to_binary(key)
          ActiveModel::Type::Binary.new.serialize(key)
        end

        def key_hash_for(key)
          # Need to unpack this as a signed integer - Postgresql and SQLite don't support unsigned integers
          Digest::SHA256.digest(key.to_s).unpack("q>").first
        end

        def key_hashes_for(keys)
          keys.map { |key| key_hash_for(key) }
        end

        def byte_size_for(payload)
          payload[:key].to_s.bytesize + payload[:value].to_s.bytesize + ESTIMATED_ROW_OVERHEAD
        end
    end
  end
end

ActiveSupport.run_load_hooks :solid_cache_entry, SolidCache::Entry
