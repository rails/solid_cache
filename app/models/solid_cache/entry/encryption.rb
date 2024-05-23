# frozen_string_literal: true

module SolidCache
  class Entry
    module Encryption
      extend ActiveSupport::Concern

      included do
        if SolidCache.configuration.encrypt?
          encrypts :value, **SolidCache.configuration.encryption_context_properties
        end
      end
    end
  end
end
