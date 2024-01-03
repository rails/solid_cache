# frozen_string_literal: true

require "test_helper"

class DeleteMatchedTest < ActiveSupport::TestCase
  setup do
    @namespace = "test-#{SecureRandom.hex}"

    @delete_cache = lookup_store(expires_in: 60, clear_with: :delete)
  end

  test "clear by truncation" do
    cache = lookup_store(expires_in: 60, clear_with: :truncate)
    write_values(cache)

    cache.clear

    assert_equal :truncate, cache.clear_with
    assert_equal 0, uncached_entry_count
  end

  test "clear by deletion" do
    cache = lookup_store(expires_in: 60, clear_with: :delete)
    write_values(cache)

    cache.clear

    assert_equal :delete, cache.clear_with
    assert_equal 0, uncached_entry_count
  end

  private
    def write_values(cache)
      20.times.map { |i| cache.write("key#{i}", "value#{i}") }
    end
end
