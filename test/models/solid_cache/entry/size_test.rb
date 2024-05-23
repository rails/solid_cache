# frozen_string_literal: true

require "test_helper"

module SolidCache
  class EntrySizeTest < ActiveSupport::TestCase
    setup do
      @encrypted = SolidCache.configuration.encrypt?
    end

    test "write and read cache entries" do
      assert_equal 0, Entry.estimated_size
    end

    test "gets exact estimate when samples sizes are big enough" do
      write_entries(value_lengths: [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ])

      assert_equal @encrypted ? 3235 : 1535, Entry.estimated_size(samples: 12)
      assert_equal @encrypted ? 3918 : 1878, Entry.estimated_size(samples: 10)
      assert_equal @encrypted ? 3922 : 1882, Entry.estimated_size(samples: 6)
    end

    test "test larger sample estimates" do
      values_lengths = with_fixed_srand(1) { 1000.times.map { (rand**2 * 1000).to_i } }
      write_entries(value_lengths: values_lengths)

      assert_equal @encrypted ? 651257 : 481257, Entry.estimated_size(samples: 1000)
      assert_equal @encrypted ? 652772 : 482262, Entry.estimated_size(samples: 501)
      with_fixed_srand(1) { assert_equal @encrypted ? 681425 : 502065, Entry.estimated_size(samples: 100) }
      with_fixed_srand(1) { assert_equal @encrypted ? 661170 : 478066, Entry.estimated_size(samples: 50) }
      with_fixed_srand(1) { assert_equal @encrypted ? 693054 : 472343, Entry.estimated_size(samples: 10) }
    end

    test "test with gaps in records estimates" do
      values_lengths = with_fixed_srand(1) { 1000.times.map { (rand**2 * 1000).to_i } }
      write_entries(value_lengths: values_lengths)
      first_mod = Entry.first.id % 3
      Entry.where("id % 3 = #{first_mod}").delete_all

      assert_equal @encrypted ? 437752 : 324532, Entry.estimated_size(samples: 1000)
      assert_equal @encrypted ? 438496 : 324936, Entry.estimated_size(samples: 500)
      with_fixed_srand(1) { assert_equal @encrypted ? 438296 : 324567, Entry.estimated_size(samples: 334) }
      with_fixed_srand(1) { assert_equal @encrypted ? 463629 : 345649, Entry.estimated_size(samples: 100) }
      with_fixed_srand(1) { assert_equal @encrypted ? 454686 : 336366, Entry.estimated_size(samples: 50) }
      with_fixed_srand(1) { assert_equal @encrypted ? 402002 : 282492, Entry.estimated_size(samples: 10) }
    end

    test "test with more gaps in records estimates" do
      values_lengths = with_fixed_srand(1) { 1000.times.map { (rand**2 * 1000).to_i } }
      write_entries(value_lengths: values_lengths)
      first_mod = Entry.first.id % 4
      Entry.where("id % 4 != #{first_mod}").delete_all

      assert_equal @encrypted ? 162804 : 120304, Entry.estimated_size(samples: 1000)
      assert_equal @encrypted ? 165713 : 121683, Entry.estimated_size(samples: 501)
      with_fixed_srand(1) { assert_equal @encrypted ? 164762 : 121240, Entry.estimated_size(samples: 250) }
      with_fixed_srand(1) { assert_equal @encrypted ? 174610 : 126976, Entry.estimated_size(samples: 100) }
      with_fixed_srand(1) { assert_equal @encrypted ? 180315 : 133014, Entry.estimated_size(samples: 50) }
      with_fixed_srand(1) { assert_equal @encrypted ? 44143 : 25596, Entry.estimated_size(samples: 10) }
    end

    test "overestimate when all samples sizes are the same" do
      # This is a pathological case where the bytes sizes are all the same, and
      # the outliers are not outliers at all. Ensure we over rather than under
      # estimate in this case.
      write_entries(value_lengths: [1] * 1000)

      assert_equal @encrypted ? 319000 : 149000, Entry.estimated_size(samples: 1000)
      assert_equal @encrypted ? 637727 : 297897, Entry.estimated_size(samples: 999)
      assert_equal @encrypted ? 478865 : 223695, Entry.estimated_size(samples: 501)
      with_fixed_srand(1) { assert_equal @encrypted ? 583869 : 272741, Entry.estimated_size(samples: 6) }
      with_fixed_srand(1) { assert_equal @encrypted ? 700634 : 327280, Entry.estimated_size(samples: 5) }
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
  end
end
