# frozen_string_literal: true

require "active_support"

module SolidCache
  class Engine < ::Rails::Engine
    isolate_namespace SolidCache

    config.solid_cache = ActiveSupport::OrderedOptions.new

    initializer "solid_cache" do |app|
      app.paths.add "config/solid_cache", with: "config/solid_cache.yml"

      SolidCache.configuration.executor = config.solid_cache.executor || app.executor

      if (config_path = Pathname.new(app.config.paths["config/solid_cache"].first)).exist?
        options = app.config_for(config_path)&.to_h&.deep_symbolize_keys || {}

        SolidCache.configuration.set_options(options)
      end
    end

    config.after_initialize do
      Rails.cache.setup! if Rails.cache.is_a?(Store)
    end
  end
end
