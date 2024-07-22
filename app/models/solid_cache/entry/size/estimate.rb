# frozen_string_literal: true

module SolidCache
  class Entry
    # # Cache size estimation
    #
    # We store the size of each cache row in the byte_size field. This allows us to estimate the size of the cache
    # by sampling those rows.
    #
    # To reduce the effect of outliers though we'll grab the N largest rows, and add their size to a sampled based
    # estimate of the size of the remaining rows.
    #
    # ## Outliers
    #
    # There is an index on the byte_size column, so we can efficiently grab the N largest rows. We also grab the
    # minimum byte_size of those rows, which we'll use as a cutoff for the non outlier sampling.
    #
    # ## Sampling
    #
    # To efficiently sample the data we use the key_hash column, which is a random 64 bit integer. There's an index
    # on key_hash and byte_size so we can grab a sum of the byte_sizes in a range of key_hash directly from that
    # index.
    #
    # To decide how big the range should be, we use the difference between the smallest and largest database IDs as
    # an estimate of the number of rows in the table. This should be a good estimate, because we delete rows in ID order
    #
    # We then calculate the fraction of the rows we want to sample by dividing the sample size by the estimated number
    # of rows.
    #
    # Then we grab the byte_size sum of the rows in the range of key_hash values excluding any rows that are larger than
    # our minimum outlier cutoff. We then divide this by the sampling fraction to get an estimate of the size of the
    # non outlier rows
    #
    # ## Equations
    #
    #  Given N samples and a key_hash range of Kmin..Kmax
    #
    #    outliers_cutoff              OC = min(byte_size of N largest rows)
    #    outliers_size                OS = sum(byte_size of N largest rows)
    #
    #    estimated number of rows     R = max(ID) - min(ID) + 1
    #    sample_fraction              F = N / R
    #    sample_range_size            S = (Kmax - Kmin) * F
    #    sample range is              K1..K2 where K1 = Kmin + rand(Kmax - S) and K2 = K1 + S
    #
    #    non_outlier_sample_size      NSS = sum(byte_size of rows in key_hash range K1..K2 where byte_size <= OC)
    #    non_outlier_estimated_size   NES = NSS / F
    #    estimated_size               ES = OS + NES
    module Size
      class Estimate
        attr_reader :samples, :max_records

        def initialize(samples:)
          @samples = samples
          @max_records ||= Entry.id_range
        end

        def size
          outliers_size + non_outlier_estimated_size
        end

        def exact?
          outliers_count < samples || sampled_fraction == 1
        end

        private
          def outliers_size
            outliers_size_count_and_cutoff[0]
          end

          def outliers_count
            outliers_size_count_and_cutoff[1]
          end

          def outliers_cutoff
            outliers_size_count_and_cutoff[2]
          end

          def outliers_size_count_and_cutoff
            @outlier_size_and_cutoff ||= Entry.uncached do
              sum, count, min = Entry.largest_byte_sizes(samples).pick(Arel.sql("sum(byte_size), count(*), min(byte_size)"))
              sum ? [sum, count, min] : [0, 0, nil]
            end
          end

          def non_outlier_estimated_size
            @non_outlier_estimated_size ||= sampled_fraction.zero? ? 0 : (sampled_non_outlier_size / sampled_fraction).round
          end

          def sampled_fraction
            @sampled_fraction ||=
              if max_records <= samples
                0
              else
                [samples.to_f / (max_records - samples), 1].min
              end
          end

          def sampled_non_outlier_size
            @sampled_non_outlier_size ||= Entry.uncached do
              Entry.in_key_hash_range(sample_range).up_to_byte_size(outliers_cutoff).sum(:byte_size)
            end
          end

          def sample_range
            if sampled_fraction == 1
              key_hash_range
            else
              start = rand(key_hash_range.begin..(key_hash_range.end - sample_range_size))
              start..(start + sample_range_size)
            end
          end

          def key_hash_range
            Entry::KEY_HASH_ID_RANGE
          end

          def sample_range_size
            @sample_range_size ||= (key_hash_range.size * sampled_fraction).to_i
          end
      end
    end
  end
end
