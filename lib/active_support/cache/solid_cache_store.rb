# frozen_string_literal: true

require "solid_cache"

module ActiveSupport
  module Cache
    SolidCacheStore = SolidCache::Store
  end
end
