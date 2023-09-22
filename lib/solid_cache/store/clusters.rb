module SolidCache
  class Store
    module Clusters
      attr_reader :primary_cluster, :clusters

      def initialize(options = {})
        super(options)

        clusters_options = options.fetch(:clusters) { [options.fetch(:cluster, {})] }

        @clusters = clusters_options.map.with_index do |cluster_options, index|
          Cluster.new(options.merge(cluster_options).merge(async_writes: index != 0))
        end

        @primary_cluster = clusters.first
      end

      def setup!
        clusters.each(&:setup!)
      end

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
          first_cluster_sync_rest_async do |cluster, async|
            failsafe(failsafe, returning: failsafe_returning) do
              cluster.with_shard_for(key, async: async) do
                yield cluster
              end
            end
          end
        end

        def writing_keys(entries, failsafe:, failsafe_returning: nil)
          first_cluster_sync_rest_async do |cluster, async|
            sharded_entries = cluster.assign_to_shards(entries)

            sharded_entries.map do |shard, entries|
              failsafe(failsafe, returning: failsafe_returning) do
                cluster.with_shard(shard, async: async) do
                  yield cluster, entries
                end
              end
            end
          end
        end

        def writing_all(failsafe:, failsafe_returning: nil)
          first_cluster_sync_rest_async do |cluster, async|
            cluster.shard_names.each do |shard|
              failsafe(failsafe, returning: failsafe_returning) do
                cluster.with_shard(shard, async: async) do
                  yield
                end
              end
            end
          end
        end

        def first_cluster_sync_rest_async
          clusters.map.with_index { |cluster, index| yield cluster, index != 0 }.first
        end
    end
  end
end
