require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)
require "solid_cache"

module Dummy
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f

    # For compatibility with applications that use this config
    config.action_controller.include_all_helpers = false

    config.cache_store = [:solid_cache_store]

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    config.solid_cache.connects_to = {
      shards: {
        default: { writing: :primary, reading: :primary_replica },
        default2: { writing: :primary_shard_one, reading: :primary_shard_one_replica },
        primary_shard_one: { writing: :primary_shard_one },
        primary_shard_two: { writing: :primary_shard_two },
        secondary_shard_one: { writing: :secondary_shard_one },
        secondary_shard_two: { writing: :secondary_shard_two }
      }
    }
  end
end
