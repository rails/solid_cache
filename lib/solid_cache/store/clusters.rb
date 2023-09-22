module SolidCache
  class Store
    module Clusters
      private
        def reading_key(key, failsafe:, failsafe_returning: nil)
          failsafe(failsafe, returning: failsafe_returning) do
            primary_cluster.with_shard_for(key) do
              yield
            end
          end
        end

        def reading_keys(keys, failsafe:, failsafe_returning: nil)
          sharded_keys = primary_cluster.assign_to_shards(keys)

          sharded_keys.map do |shard, keys|
            failsafe(failsafe, returning: failsafe_returning) do
              primary_cluster.with_shard(shard) do
                yield keys
              end
            end
          end
        end


        def writing_key(key, failsafe:, failsafe_returning: nil)
          each_cluster do |cluster, async|
            failsafe(failsafe, returning: failsafe_returning) do
              cluster.with_shard_for(key, async: async) do
                yield cluster
              end
            end
          end
        end

        def writing_keys(entries, failsafe:, failsafe_returning: nil)
          each_cluster do |cluster, async|
            sharded_entries = cluster.assign_to_shards(entries)

            sharded_entries.map do |shard, entries|
              failsafe(failsafe, returning: failsafe_returning) do
                cluster.with_shard(shard, async: async) do
                  yield cluster, shard, entries
                end
              end
            end
          end
        end

        def writing_all(failsafe:, failsafe_returning: nil)
          each_cluster do |cluster, async|
            cluster.shard_names.each do |shard|
              failsafe(failsafe, returning: failsafe_returning) do
                cluster.with_shard(shard, async: async) do
                  yield
                end
              end
            end
          end
        end

        def each_cluster
          clusters.map.with_index { |cluster, index| yield cluster, index != 0 }.first
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
