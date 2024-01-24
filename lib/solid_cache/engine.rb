# frozen_string_literal: true

require "active_support"

module SolidCache
  class Engine < ::Rails::Engine
    isolate_namespace SolidCache

    config.solid_cache = ActiveSupport::OrderedOptions.new

    initializer "solid_cache", before: :run_prepare_callbacks do |app|
      config.solid_cache.executor ||= app.executor

      SolidCache.executor = config.solid_cache.executor
      SolidCache.connects_to = config.solid_cache.connects_to
      if config.solid_cache.key_hash_stage
        unless [:ignored, :unindexed, :indexed].include?(config.solid_cache.key_hash_stage)
          raise "ArgumentError, :key_hash_stage must be :ignored, :unindexed or :indexed"
        end
        SolidCache.key_hash_stage = config.solid_cache.key_hash_stage
      end
    end

    config.after_initialize do
      Rails.cache.setup! if Rails.cache.is_a?(Store)
    end
  end
end
