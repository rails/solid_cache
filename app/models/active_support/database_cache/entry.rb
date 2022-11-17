module ActiveSupport::DatabaseCache
  class Entry < ApplicationRecord
    class << self
      def set(key, value, expires_at: nil)
        create(key: key, value: value, expires_at: expires_at) unless expired?(expires_at)
      end

      def get(key)
        value, expires_at = where(key: key).pluck(:value, :expires_at).first
        value unless expired?(expires_at)
      end

      def expired?(expires_at)
        expires_at && expires_at < Time.now
      end
    end
  end
end
