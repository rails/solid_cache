module SolidCache
  class Store
    module Operations
      private
        def delete_matched_entries(matcher, batch_size)
          writing do
            failsafe :delete_matched do
              Entry.delete_matched(matcher, batch_size: batch_size)
            end
          end
        end

        def increment_entry(key, amount)
          writing_key(key, failsafe: :increment) do
            Entry.increment(key, amount)
          end
        end

        def decrement_entry(key, amount)
          writing_key(key, failsafe: :decrement) do
            Entry.increment(key, -amount)
          end
        end

        def get_entry(key)
          failsafe(:read_entry) do
            primary_cluster.reading_shard(normalized_key: key) do
              Entry.get(key)
            end
          end
        end

        def get_entries(keys)
          primary_cluster.across_shards(list: keys) do |shard, keys|
            failsafe(:read_multi_mget, returning: {}) do
              primary_cluster.with_shard(shard) do
                Entry.get_all(keys)
              end
            end
          end
        end

        def set_entry(key, payload)
          writing_key(key, failsafe: :write_entry, failsafe_returning: false) do |cluster|
            Entry.set(key, payload)
            cluster.trim(1)
            true
          end
        end

        def set_entries(entries)
          writing_list(entries) do |cluster, shard, entries|
            failsafe(:write_multi_entries, returning: false) do
              cluster.with_shard(shard) do
                Entry.set_all(entries)
                cluster.trim(entries.count)
                true
              end
            end
          end
        end

        def delete_entry_internal(key)
          writing_key(key, failsafe: :delete_entry, failsafe_returning: false) do
            Entry.delete_by_key(key)
          end
        end


        def writing_key(key, failsafe:, failsafe_returning: nil)
          writing_clusters do |cluster|
            failsafe(failsafe, returning: failsafe_returning) do
              cluster.writing_shard(normalized_key: key) do
                yield cluster
              end
            end
          end
        end

        def writing_list(list)
          writing_clusters do |cluster|
            cluster.across_shards(list: list) do |shard, list|
              yield cluster, shard, list
            end
          end
        end

        def writing
          writing_clusters do |cluster|
            cluster.writing_all_shards do
              yield
            end
          end
        end

        def writing_clusters
          clusters.map { |cluster| yield cluster }.first
        end

        def failsafe(method, returning: nil)
          yield
        rescue ActiveRecord::ActiveRecordError => error
          ActiveSupport.error_reporter&.report(error, handled: true, severity: :warning)
          @error_handler&.call(method: method, exception: error, returning: returning)
          returning
        end
    end
  end
end
