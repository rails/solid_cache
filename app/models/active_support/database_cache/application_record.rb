module ActiveSupport
  module DatabaseCache
    class ApplicationRecord < ActiveRecord::Base
      self.abstract_class = true
    end
  end
end
