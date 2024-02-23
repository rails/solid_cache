# frozen_string_literal: true

require "test_helper"

module SolidCache
  class EntrySizeEstimateTest < ActiveSupport::TestCase
    test "write and read cache entries" do
      assert_equal 0, estimate(samples: 10)
    end

    test "gets exact estimate when samples sizes are big enough" do
      write_entries(value_lengths: [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ])

      assert_equal 415, estimate(samples: 12)
      assert_equal 415, estimate(samples: 10)
      assert_equal 456, estimate(samples: 6)
      assert_equal 457, estimate(samples: 5)
    end

    test "test larger sample estimates" do
      values_lengths = with_fixed_srand(1) { 1000.times.map { (rand**2 * 1000).to_i } }
      write_entries(value_lengths: values_lengths)

      assert_equal 369257, estimate(samples: 1000)
      assert_equal 369550, estimate(samples: 500)
      with_fixed_srand(1) { assert_equal 383576, estimate(samples: 100) }
      with_fixed_srand(1) { assert_equal 357109, estimate(samples: 50) }
      with_fixed_srand(1) { assert_equal 326614, estimate(samples: 10) }
    end

    test "test with gaps in records estimates" do
      values_lengths = with_fixed_srand(1) { 1000.times.map { (rand**2 * 1000).to_i } }
      write_entries(value_lengths: values_lengths)
      first_mod = Entry.first.id % 3
      Entry.where("id % 3 = #{first_mod}").delete_all

      assert_equal 249940, estimate(samples: 1000)
      assert_equal 250037, estimate(samples: 500)
      with_fixed_srand(1) { assert_equal 249354, estimate(samples: 334) }
      with_fixed_srand(1) { assert_equal 267523, estimate(samples: 100) }
      with_fixed_srand(1) { assert_equal 257970, estimate(samples: 50) }
      with_fixed_srand(1) { assert_equal 203365, estimate(samples: 10) }
    end

    test "test with more gaps in records estimates" do
      values_lengths = with_fixed_srand(1) { 1000.times.map { (rand**2 * 1000).to_i } }
      write_entries(value_lengths: values_lengths)
      first_mod = Entry.first.id % 4
      Entry.where("id % 4 != #{first_mod}").delete_all

      assert_equal 92304, estimate(samples: 1000)
      assert_equal 92592, estimate(samples: 500)
      with_fixed_srand(1) { assert_equal 92519, estimate(samples: 250) }
      with_fixed_srand(1) { assert_equal 95475, estimate(samples: 100) }
      with_fixed_srand(1) { assert_equal 101601, estimate(samples: 50) }
      with_fixed_srand(1) { assert_equal 13362, estimate(samples: 10) }
    end

    test "overestimate when all samples sizes are the same" do
      # This is a pathological case where the bytes sizes are all the same, and
      # the outliers are not outliers at all. Ensure we over rather than under
      # estimate in this case.
      write_entries(value_lengths: [1] * 1000)

      assert_equal 37000, estimate(samples: 1000)
      assert_equal 73963, estimate(samples: 999)
      assert_equal 55500, estimate(samples: 500)
      with_fixed_srand(1) { assert_equal 67648, estimate(samples: 6) }
      with_fixed_srand(1) { assert_equal 81178, estimate(samples: 5) }
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
