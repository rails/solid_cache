module ActiveSupport
  module DatabaseCache
    class Record < ActiveRecord::Base
      self.abstract_class = true
    end
  end
end

ActiveSupport.run_load_hooks :active_support_database_cache, ActiveSupport::DatabaseCache::Record
