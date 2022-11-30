module ActiveSupport
  module DatabaseCache
    class ApplicationRecord < ActiveRecord::Base
      self.abstract_class = true
    end
  end
end

ActiveSupport.run_load_hooks :active_storage_database_cache, ActiveSupport::DatabaseCache::ApplicationRecord
