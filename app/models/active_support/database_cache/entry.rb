module ActiveSupport::DatabaseCache
  class Entry < ApplicationRecord
    class << self
      def set(key, value, expires_at: nil)
        upsert_all([{key: key, value: value, expires_at: expires_at}], unique_by: upsert_unique_by, update_only: [:value, :expires_at])
      end

      def set_all(payloads, expires_at: nil)
        upsert_all(payloads, unique_by: upsert_unique_by, update_only: [:value, :expires_at])
      end

      def get(key)
        where(key: key).pick(:value)
      end

      def get_all(keys)
        where(key: keys).pluck(:key, :value).to_h
      end

      def delete(key)
        where(key: key).delete_all.nonzero?
      end

      def increment(key, amount)
        transaction do
          amount += lock.get(key).to_i
          set(key, amount)
          amount
        end
      end

      private
        def upsert_unique_by
          connection.supports_insert_conflict_target? ? :key : nil
        end
    end
  end
end
