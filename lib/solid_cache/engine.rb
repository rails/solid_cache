# frozen_string_literal: true

require "active_support"
require "active_record"

module SolidCache
  class Engine < ::Rails::Engine
    isolate_namespace SolidCache

    config.solid_cache = ActiveSupport::OrderedOptions.new

    initializer "solid_cache.config", before: :initialize_cache do |app|
      config_paths = %w[config/cache config/solid_cache]

      config_paths.each do |path|
        app.paths.add path, with: ENV["SOLID_CACHE_CONFIG"] || "#{path}.yml"
      end

      config_pathname = config_paths.map { |path| Pathname.new(app.config.paths[path].first) }.find(&:exist?)

      options = config_pathname ? app.config_for(config_pathname).to_h.deep_symbolize_keys : {}

      options[:connects_to] = config.solid_cache.connects_to if config.solid_cache.connects_to
      options[:size_estimate_samples] = config.solid_cache.size_estimate_samples if config.solid_cache.size_estimate_samples
      options[:encrypt] = config.solid_cache.encrypt if config.solid_cache.encrypt
      options[:encryption_context_properties] = config.solid_cache.encryption_context_properties if config.solid_cache.encryption_context_properties

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

    config.after_initialize do
      if SolidCache.configuration.encrypt? && Record.connection.adapter_name == "PostgreSQL" && Rails::VERSION::MAJOR <= 7
        raise \
          "Cannot enable encryption for Solid Cache: in Rails 7, Active Record Encryption does not support " \
          "encrypting binary columns on PostgreSQL"
      end
    end
  end
end
