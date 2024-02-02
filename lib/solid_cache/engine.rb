# frozen_string_literal: true

require "active_support"

module SolidCache
  class Engine < ::Rails::Engine
    isolate_namespace SolidCache

    config.solid_cache = ActiveSupport::OrderedOptions.new

    initializer "solid_cache.config", before: :initialize_cache do |app|
      app.paths.add "config/solid_cache", with: ENV["SOLID_CACHE_CONFIG"] || "config/solid_cache.yml"

      options = {}
      if (config_path = Pathname.new(app.config.paths["config/solid_cache"].first)).exist?
        options = app.config_for(config_path).to_h.deep_symbolize_keys
      end

      options[:connects_to] = config.solid_cache.connects_to if config.solid_cache.connects_to
      options[:size_estimate_samples] = config.solid_cache.size_estimate_samples if config.solid_cache.size_estimate_samples

      SolidCache.configuration = SolidCache::Configuration.new(**options)

      if config.solid_cache.key_hash_stage
        ActiveSupport.deprecator.warn("config.solid_cache.key_hash_stage is deprecated and has no effect.")
      end
    end

    initializer "solid_cache.app_executor", before: :run_prepare_callbacks do |app|
      SolidCache.executor = config.solid_cache.executor || app.executor
    end

    config.after_initialize do
      Rails.cache.setup! if Rails.cache.is_a?(Store)
    end
  end
end
