# frozen_string_literal: true

require "test_helper"

module SolidCache
  class EntrySizeEstimateTest < ActiveSupport::TestCase
    setup do
      @encrypted = SolidCache.configuration.encrypt?
    end

    test "write and read cache entries" do
      assert_equal 0, estimate(samples: 10)
    end

    test "gets exact estimate when samples sizes are big enough" do
      write_entries(value_lengths: [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ])

      assert_equal @encrypted ? 3235 : 1535, estimate(samples: 12)
      assert_equal @encrypted ? 3235 : 1535, estimate(samples: 10)
      assert_equal @encrypted ? 3558 : 1688, estimate(samples: 6)
      assert_equal @encrypted ? 3559 : 1689, estimate(samples: 5)
    end

    test "test larger sample estimates" do
      values_lengths = with_fixed_srand(1) { 1000.times.map { (rand**2 * 1000).to_i } }
      write_entries(value_lengths: values_lengths)

      assert_equal @encrypted ? 651257 : 481257, estimate(samples: 1000)
      assert_equal @encrypted ? 651832 : 481662, estimate(samples: 500)
      with_fixed_srand(1) { assert_equal @encrypted ? 680804 : 501624, estimate(samples: 100) }
      with_fixed_srand(1) { assert_equal @encrypted ? 660541 : 477621, estimate(samples: 50) }
      with_fixed_srand(1) { assert_equal @encrypted ? 692368 : 471878, estimate(samples: 10) }
    end

    test "test with gaps in records estimates" do
      values_lengths = with_fixed_srand(1) { 1000.times.map { (rand**2 * 1000).to_i } }
      write_entries(value_lengths: values_lengths)
      first_mod = Entry.first.id % 3
      Entry.where("id % 3 = #{first_mod}").delete_all

      assert_equal @encrypted ? 437752 : 324532, estimate(samples: 1000)
      assert_equal @encrypted ? 438131 : 324741, estimate(samples: 500)
      with_fixed_srand(1) { assert_equal @encrypted ? 437166 : 323946, estimate(samples: 334) }
      with_fixed_srand(1) { assert_equal @encrypted ? 462859 : 345103, estimate(samples: 100) }
      with_fixed_srand(1) { assert_equal @encrypted ? 453859 : 335770, estimate(samples: 50) }
      with_fixed_srand(1) { assert_equal @encrypted ? 401216 : 281944, estimate(samples: 10) }
    end

    test "test with more gaps in records estimates" do
      values_lengths = with_fixed_srand(1) { 1000.times.map { (rand**2 * 1000).to_i } }
      write_entries(value_lengths: values_lengths)
      first_mod = Entry.first.id % 4
      Entry.where("id % 4 != #{first_mod}").delete_all

      assert_equal @encrypted ? 162804 : 120304, estimate(samples: 1000)
      assert_equal @encrypted ? 165348 : 121488, estimate(samples: 500)
      with_fixed_srand(1) { assert_equal @encrypted ? 164704 : 121188, estimate(samples: 250) }
      with_fixed_srand(1) { assert_equal @encrypted ? 174266 : 126768, estimate(samples: 100) }
      with_fixed_srand(1) { assert_equal @encrypted ? 179794 : 132657, estimate(samples: 50) }
      with_fixed_srand(1) { assert_equal @encrypted ? 44016 : 25537, estimate(samples: 10) }
    end

    test "overestimate when all samples sizes are the same" do
      # This is a pathological case where the bytes sizes are all the same, and
      # the outliers are not outliers at all. Ensure we over rather than under
      # estimate in this case.
      write_entries(value_lengths: [1] * 1000)

      assert_equal @encrypted ? 319000 : 149000, estimate(samples: 1000)
      assert_equal @encrypted ? 637681 : 297851, estimate(samples: 999)
      assert_equal @encrypted ? 478500 : 223500, estimate(samples: 500)
      with_fixed_srand(1) { assert_equal @encrypted ? 583238 : 272422, estimate(samples: 6) }
      with_fixed_srand(1) { assert_equal @encrypted ? 699886 : 326906, estimate(samples: 5) }
    end

    private
      def write_entries(value_lengths:)
        Entry.write_multi(value_lengths.map.with_index { |value_length, index| { key: "key#{index.to_s.rjust(5, "0")}", value: "a" * value_length } })
      end

      def with_fixed_srand(seed)
        old_srand = srand(seed)
        yield
      ensure
        srand(old_srand)
      end

      def estimate(samples:)
        Entry::Size::Estimate.new(samples: samples).size
      end
  end
end
