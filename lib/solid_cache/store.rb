# frozen_string_literal: true

module SolidCache
  class Store < ActiveSupport::Cache::Store
    include Api, Connections, Entries, Execution, Expiry, Failsafe, Stats
    prepend ActiveSupport::Cache::Strategy::LocalCache

    def initialize(options = {})
      super(SolidCache.configuration.store_options.merge(options))
    end

    def self.supports_cache_versioning?
      true
    end

    def setup!
      super
    end
  end
end
