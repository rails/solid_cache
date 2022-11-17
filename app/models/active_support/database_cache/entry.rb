module ActiveSupport::DatabaseCache
  class Entry < ApplicationRecord
    class << self
      def set(key, value, expires_at: nil)
        upsert({key: key, value: value, expires_at: expires_at})
      end

      def get(key)
        where(key: key).pick(:value)
      end

      def delete(key)
        where(key: key).delete_all
      end
    end
  end
end
