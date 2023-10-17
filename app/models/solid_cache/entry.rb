module SolidCache
  class Entry < Record
    # This is all quite awkward but it achieves a couple of performance aims
    # 1. We skip the query cache
    # 2. We avoid the overhead of building queries and active record objects
    class << self
      def write(key, value)
        upsert_all_no_query_cache([ { key: key, value: value } ])
      end

      def write_multi(payloads)
        upsert_all_no_query_cache(payloads)
      end

      def read(key)
        select_all_no_query_cache(get_sql, to_binary(key)).first
      end

      def read_multi(keys)
        serialized_keys = keys.map { |key| to_binary(key) }
        select_all_no_query_cache(get_all_sql(serialized_keys), serialized_keys).to_h
      end

      def delete_by_key(key)
        delete_no_query_cache(:key, to_binary(key))
      end

      def delete_matched(matcher, batch_size:)
        like_matcher = arel_table[:key].matches(matcher, nil, true)
        where(like_matcher).select(:id).find_in_batches(batch_size: batch_size) do |entries|
          delete_no_query_cache(:id, entries.map(&:id))
        end
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
            amount += lock.where(key: key).pick(:value).to_i
            write(key, amount)
            amount
          end
        end
      end

      def decrement(key, amount)
        increment(key, -amount)
      end

      def id_range
        uncached do
          pick(Arel.sql("max(id) - min(id) + 1")) || 0
        end
      end

      def expire(count, max_age:, max_entries:)
        if (ids = expiry_candidate_ids(count, max_age: max_age, max_entries: max_entries)).any?
          delete(ids)
        end
      end

      private
        def upsert_all_no_query_cache(attributes)
          insert_all = ActiveRecord::InsertAll.new(self, attributes, unique_by: upsert_unique_by, on_duplicate: :update, update_only: [ :value ])
          sql = connection.build_insert_sql(ActiveRecord::InsertAll::Builder.new(insert_all))

          message = +"#{self} "
          message << "Bulk " if attributes.many?
          message << "Upsert"
          # exec_query does not clear the query cache, exec_insert_all does
          connection.exec_query sql, message
        end

        def upsert_unique_by
          connection.supports_insert_conflict_target? ? :key : nil
        end

        def get_sql
          @get_sql ||= build_sql(where(key: "placeholder").select(:value))
        end

        def get_all_sql(keys)
          if connection.prepared_statements?
            @get_all_sql_binds ||= {}
            @get_all_sql_binds[keys.count] ||= build_sql(where(key: keys).select(:key, :value))
          else
            @get_all_sql_no_binds ||= build_sql(where(key: [ "placeholder1", "placeholder2" ]).select(:key, :value)).gsub("?, ?", "?")
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
              result = connection.select_all(sanitize_sql([ query, values ]), "#{name} Load", nil, preparable: false)
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

        def expiry_candidate_ids(count, max_age:, max_entries:)
          cache_full = max_entries && max_entries < id_range
          min_created_at = max_age.seconds.ago

          uncached do
            order(:id)
              .limit(count * 3)
              .pluck(:id, :created_at)
              .filter_map { |id, created_at| id if cache_full || created_at < min_created_at }
              .sample(count)
          end
        end
    end
  end
end

ActiveSupport.run_load_hooks :solid_cache_entry, SolidCache::Entry
