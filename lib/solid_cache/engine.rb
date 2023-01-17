require "active_support"
require "solid_cache"

module SolidCache
  class Engine < ::Rails::Engine
    isolate_namespace SolidCache
  end
end
