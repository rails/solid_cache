module SolidCache
  class Store < ActiveSupport::Cache::Store
    DEFAULT_ERROR_HANDLER = -> (method:, returning:, exception:) do
      if logger
        logger.error { "SolidCacheStore: #{method} failed, returned #{returning.inspect}: #{exception.class}: #{exception.message}" }
      end
    end

    include Clusters, Entries, Api
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
