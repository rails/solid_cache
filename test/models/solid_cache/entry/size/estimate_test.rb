# frozen_string_literal: true

require "test_helper"

module SolidCache
  class EntrySizeEstimateTest < ActiveSupport::TestCase
    test "write and read cache entries" do
      assert_equal 0, estimate(samples: 10)
    end

    test "gets exact estimate when samples sizes are big enough" do
      write_entries(value_lengths: [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ])

      assert_equal 1535, estimate(samples: 12)
      assert_equal 1535, estimate(samples: 10)
      assert_equal 1688, estimate(samples: 6)
      assert_equal 1689, estimate(samples: 5)
    end

    test "test larger sample estimates" do
      values_lengths = with_fixed_srand(1) { 1000.times.map { (rand**2 * 1000).to_i } }
      write_entries(value_lengths: values_lengths)

      assert_equal 481257, estimate(samples: 1000)
      assert_equal 481662, estimate(samples: 500)
      with_fixed_srand(1) { assert_equal 501624, estimate(samples: 100) }
      with_fixed_srand(1) { assert_equal 477621, estimate(samples: 50) }
      with_fixed_srand(1) { assert_equal 471878, estimate(samples: 10) }
    end

    test "test with gaps in records estimates" do
      values_lengths = with_fixed_srand(1) { 1000.times.map { (rand**2 * 1000).to_i } }
      write_entries(value_lengths: values_lengths)
      first_mod = Entry.first.id % 3
      Entry.where("id % 3 = #{first_mod}").delete_all

      assert_equal 324532, estimate(samples: 1000)
      assert_equal 324741, estimate(samples: 500)
      with_fixed_srand(1) { assert_equal 323946, estimate(samples: 334) }
      with_fixed_srand(1) { assert_equal 345103, estimate(samples: 100) }
      with_fixed_srand(1) { assert_equal 335770, estimate(samples: 50) }
      with_fixed_srand(1) { assert_equal 281944, estimate(samples: 10) }
    end

    test "test with more gaps in records estimates" do
      values_lengths = with_fixed_srand(1) { 1000.times.map { (rand**2 * 1000).to_i } }
      write_entries(value_lengths: values_lengths)
      first_mod = Entry.first.id % 4
      Entry.where("id % 4 != #{first_mod}").delete_all

      assert_equal 120304, estimate(samples: 1000)
      assert_equal 121488, estimate(samples: 500)
      with_fixed_srand(1) { assert_equal 121188, estimate(samples: 250) }
      with_fixed_srand(1) { assert_equal 126768, estimate(samples: 100) }
      with_fixed_srand(1) { assert_equal 132657, estimate(samples: 50) }
      with_fixed_srand(1) { assert_equal 25537, estimate(samples: 10) }
    end

    test "overestimate when all samples sizes are the same" do
      # This is a pathological case where the bytes sizes are all the same, and
      # the outliers are not outliers at all. Ensure we over rather than under
      # estimate in this case.
      write_entries(value_lengths: [1] * 1000)

      assert_equal 149000, estimate(samples: 1000)
      assert_equal 297851, estimate(samples: 999)
      assert_equal 223500, estimate(samples: 500)
      with_fixed_srand(1) { assert_equal 272422, estimate(samples: 6) }
      with_fixed_srand(1) { assert_equal 326906, estimate(samples: 5) }
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
