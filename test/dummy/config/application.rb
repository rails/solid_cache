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

    config.cache_store = :solid_cache_store

    config.active_record.encryption.key_provider = ActiveRecord::Encryption::EnvelopeEncryptionKeyProvider.new

    if ENV["SOLID_CACHE_CONFIG"] == "config/cache_encrypted_custom.yml"
      config.solid_cache.encryption_context_properties = {
        encryptor: ActiveRecord::Encryption::Encryptor.new,
        message_serializer: ActiveRecord::Encryption::MessageSerializer.new
      }
    end
  end
end
