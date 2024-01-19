# frozen_string_literal: true

module SolidCache
  class Entry
    module Expiration
      extend ActiveSupport::Concern

      class_methods do
        def id_range
          uncached do
            pick(Arel.sql("max(id) - min(id) + 1")) || 0
          end
        end

        def expire(count, max_age:, max_entries:)
          if (ids = expiry_candidate_ids(count, max_age: max_age, max_entries: max_entries)).any?
            delete(ids)
          end
        end

        private
          def expiry_candidate_ids(count, max_age:, max_entries:)
            cache_full = max_entries && max_entries < id_range
            return [] unless cache_full || max_age

            # In the case of multiple concurrent expiry operations, it is desirable to
            # reduce the overlap of entries being addressed by each. For that reason,
            # retrieve more ids than are being expired, and use random
            # sampling to reduce that number to the actual intended count.
            retrieve_count = count * 3

            uncached do
              candidates = order(:id).limit(retrieve_count)

              candidate_ids = if cache_full
                candidates.pluck(:id)
              else
                min_created_at = max_age.seconds.ago
                candidates.pluck(:id, :created_at)
                          .filter_map { |id, created_at| id if created_at < min_created_at }
              end

              candidate_ids.sample(count)
            end
          end
      end
    end
  end
end
