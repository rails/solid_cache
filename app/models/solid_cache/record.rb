module SolidCache
  class Record < ActiveRecord::Base
    self.abstract_class = true
  end
end

ActiveSupport.run_load_hooks :solid_cache, SolidCache::Record
