# frozen_string_literal: true

module SolidCache
  class Entry
    module Size
      # Moving average cache size estimation
      #
      # To reduce variability in the cache size estimate, we'll use a moving average of the previous 20 estimates.
      # The estimates are stored directly in the cache, under the "__solid_cache_entry_size_moving_average_estimates" key.
      #
      # We'll remove the largest and smallest estimates, and then average remaining ones.
      class MovingAverageEstimate
        ESTIMATES_KEY = "__solid_cache_entry_size_moving_average_estimates"
        MAX_RETAINED_ESTIMATES = 50
        TARGET_SAMPLED_FRACTION = 0.0005

        attr_reader :samples, :size
        delegate :exact?, to: :estimate

        def initialize(samples:)
          @samples = samples
          @estimate = Estimate.new(samples: samples)
          values = latest_values
          @size = (values.sum / values.size.to_f).round
          write_values(values)
        end

        private
          attr_reader :estimate

          def previous_values
            Entry.read(ESTIMATES_KEY).presence&.split("|")&.map(&:to_i) || []
          end

          def latest_value
            estimate.size
          end

          def latest_values
            (previous_values + [latest_value]).last(retained_estimates)
          end

          def write_values(values)
            Entry.write(ESTIMATES_KEY, values.join("|"))
          end

          def retained_estimates
            [retained_estimates_for_target_fraction, MAX_RETAINED_ESTIMATES].min
          end

          def retained_estimates_for_target_fraction
            (estimate.max_records / samples * TARGET_SAMPLED_FRACTION).floor + 1
          end
      end
    end
  end
end
