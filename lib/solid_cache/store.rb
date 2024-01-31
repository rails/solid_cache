# frozen_string_literal: true

module SolidCache
  class Store < ActiveSupport::Cache::Store
    include Api, Clusters, Entries, Failsafe
    prepend ActiveSupport::Cache::Strategy::LocalCache

    def initialize(options = {})
      super(SolidCache.store_options.merge(options))
    end

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
