module ActiveSupport::DatabaseCache
  class Entry < ApplicationRecord
    class << self
      def set(key, value, expires_at: nil)
        upsert_all([{key: key, value: value, expires_at: expires_at}], unique_by: :key, update_only: [:value, :expires_at])
      end

      def set_all(payloads, expires_at: nil)
        upsert_all(payloads, unique_by: :key, update_only: [:value, :expires_at])
      end

      def get(key)
        pick_value(key)
      end

      def get_all(keys)
        where(key: keys).pluck(:key, :value).to_h
      end

      def delete(key)
        where(key: key).delete_all.nonzero?
      end

      def increment(key, amount)
        transaction do
          amount += lock.pick_value(key).to_i
          set(key, amount)
          amount
        end
      end

      def pick_value(key)
        where(key: key).pick(:value)
      end

    end
  end
end
