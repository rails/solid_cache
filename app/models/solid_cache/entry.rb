# frozen_string_literal: true

module SolidCache
  class Entry < Record
    include Expiration

    ID_BYTE_SIZE = 8
    CREATED_AT_BYTE_SIZE = 8
    KEY_HASH_BYTE_SIZE = 8
    VALUE_BYTE_SIZE = 4
    FIXED_SIZE_COLUMNS_BYTE_SIZE = ID_BYTE_SIZE + CREATED_AT_BYTE_SIZE + KEY_HASH_BYTE_SIZE + VALUE_BYTE_SIZE

    self.ignored_columns += [ :key_hash, :byte_size] if SolidCache.configuration.key_hash_stage == :ignored

    class << self
      def write(key, value)
        upsert_all_no_query_cache([ { key: key, value: value } ])
      end

      def write_multi(payloads)
        upsert_all_no_query_cache(payloads)
      end

      def read(key)
        result = select_all_no_query_cache(get_sql, lookup_value(key)).first
        result[1] if result&.first == key
      end

      def read_multi(keys)
        key_hashes = keys.map { |key| lookup_value(key) }
        results = select_all_no_query_cache(get_all_sql(key_hashes), key_hashes).to_h
        results.except!(results.keys - keys)
      end

      def delete_by_key(key)
        delete_no_query_cache(lookup_column, lookup_value(key))
      end

      def delete_multi(keys)
        serialized_keys = keys.map { |key| lookup_value(key) }
        delete_no_query_cache(lookup_column, serialized_keys)
      end

      def clear_truncate
        connection.truncate(table_name)
      end

      def clear_delete
        in_batches.delete_all
      end

      def increment(key, amount)
        transaction do
          uncached do
            result = lock.where(lookup_column => lookup_value(key)).pick(:key, :value)
            amount += result[1].to_i if result&.first == key
            write(key, amount)
            amount
          end
        end
      end

      def decrement(key, amount)
        increment(key, -amount)
      end

      private
        def upsert_all_no_query_cache(payloads)
          insert_all = ActiveRecord::InsertAll.new(
            self,
            add_key_hash_and_byte_size(payloads),
            unique_by: upsert_unique_by,
            on_duplicate: :update,
            update_only: upsert_update_only
          )
          sql = connection.build_insert_sql(ActiveRecord::InsertAll::Builder.new(insert_all))

          message = +"#{self} "
          message << "Bulk " if payloads.many?
          message << "Upsert"
          # exec_query_method does not clear the query cache, exec_insert_all does
          connection.send exec_query_method, sql, message
        end

        def add_key_hash_and_byte_size(payloads)
          payloads.map do |payload|
            payload.dup.tap do |payload|
              if key_hash?
                payload[:key_hash] = key_hash_for(payload[:key])
                payload[:byte_size] = byte_size_for(payload)
              end
            end
          end
        end

        def key_hash?
          @key_hash ||= [ :indexed, :unindexed ].include?(SolidCache.configuration.key_hash_stage) &&
            connection.column_exists?(table_name, :key_hash)
        end

        def key_hash_indexed?
          key_hash? && SolidCache.configuration.key_hash_stage == :indexed
        end

        def lookup_column
          key_hash_indexed? ? :key_hash : :key
        end

        def lookup_value(key)
          key_hash_indexed? ? key_hash_for(key) : to_binary(key)
        end

        def lookup_placeholder
          key_hash_indexed? ? 1 : "placeholder"
        end

        def exec_query_method
          connection.respond_to?(:internal_exec_query) ? :internal_exec_query : :exec_query
        end

        def upsert_unique_by
          connection.supports_insert_conflict_target? ? lookup_column : nil
        end

        def upsert_update_only
          if key_hash_indexed?
            [ :key, :value, :byte_size ]
          elsif key_hash?
            [ :value, :key_hash, :byte_size ]
          else
            [ :value ]
          end
        end

        def get_sql
          @get_sql ||= {}
          @get_sql[lookup_column] ||= build_sql(where(lookup_column => lookup_placeholder).select(:key, :value))
        end

        def get_all_sql(key_hashes)
          if connection.prepared_statements?
            @get_all_sql_binds ||= {}
            @get_all_sql_binds[[key_hashes.count, lookup_column]] ||= build_sql(where(lookup_column => key_hashes).select(:key, :value))
          else
            @get_all_sql_no_binds ||= {}
            @get_all_sql_no_binds[lookup_column] ||= build_sql(where(lookup_column => [ lookup_placeholder, lookup_placeholder ]).select(:key, :value)).gsub("?, ?", "?")
          end
        end

        def build_sql(relation)
          collector = Arel::Collectors::Composite.new(
            Arel::Collectors::SQLString.new,
            Arel::Collectors::Bind.new,
          )

          connection.visitor.compile(relation.arel.ast, collector)[0]
        end

        def select_all_no_query_cache(query, values)
          uncached do
            if connection.prepared_statements?
              result = connection.select_all(sanitize_sql(query), "#{name} Load", Array(values), preparable: true)
            else
              result = connection.select_all(sanitize_sql([ query, values ]), "#{name} Load", Array(values), preparable: false)
            end

            result.cast_values(SolidCache::Entry.attribute_types)
          end
        end

        def delete_no_query_cache(attribute, values)
          uncached do
            relation = where(attribute => values)
            sql = connection.to_sql(relation.arel.compile_delete(relation.table[primary_key]))

            # exec_delete does not clear the query cache
            if connection.prepared_statements?
              connection.exec_delete(sql, "#{name} Delete All", Array(values)).nonzero?
            else
              connection.exec_delete(sql, "#{name} Delete All").nonzero?
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

        def byte_size_for(payload)
          payload[:key].to_s.bytesize + payload[:value].to_s.bytesize + FIXED_SIZE_COLUMNS_BYTE_SIZE
        end
    end
  end
end

ActiveSupport.run_load_hooks :solid_cache_entry, SolidCache::Entry
