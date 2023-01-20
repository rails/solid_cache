require "active_support"
require "solid_cache"

module SolidCache
  class Engine < ::Rails::Engine
    isolate_namespace SolidCache

    config.solid_cache = ActiveSupport::OrderedOptions.new

    initializer "solid_cache", before: :run_prepare_callbacks do |app|
      config.solid_cache.executor ||= app.executor

      SolidCache.executor = config.solid_cache.executor
      SolidCache.connects_to = config.solid_cache.connects_to
    end
  end
end
