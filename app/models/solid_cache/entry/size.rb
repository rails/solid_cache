# frozen_string_literal: true

module SolidCache
  class Entry
    module Size
      extend ActiveSupport::Concern

      included do
        scope :largest_byte_sizes, -> (limit) { from(order(byte_size: :desc).limit(limit).select(:byte_size)) }
        scope :in_key_hash_range, -> (range) { where(key_hash: range) }
        scope :up_to_byte_size, -> (cutoff) { where("byte_size <= ?", cutoff) }
      end

      class_methods do
        def estimated_size(samples: SolidCache.configuration.size_estimate_samples)
          MovingAverageEstimate.new(samples: samples).size
        end
      end
    end
  end
end
