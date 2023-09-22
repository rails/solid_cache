require "solid_cache/cluster"

module SolidCache
  class Store < ActiveSupport::Cache::Store
    require "solid_cache/store/clusters"
    require "solid_cache/store/operations"
    require "solid_cache/store/api"

    DEFAULT_ERROR_HANDLER = -> (method:, returning:, exception:) do
      if logger
        logger.error { "SolidCacheStore: #{method} failed, returned #{returning.inspect}: #{exception.class}: #{exception.message}" }
      end
    end

    include Clusters, Operations, Api
    prepend ActiveSupport::Cache::Strategy::LocalCache

    def self.supports_cache_versioning?
      true
    end

    def setup!
      super
    end

    def stats
      primary_cluster.stats
    end
  end
end
