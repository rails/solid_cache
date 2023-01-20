module SolidCache
  class Record < ActiveRecord::Base
    self.abstract_class = true

    connects_to **SolidCache.connects_to if SolidCache.connects_to
  end
end

ActiveSupport.run_load_hooks :solid_cache, SolidCache::Record
