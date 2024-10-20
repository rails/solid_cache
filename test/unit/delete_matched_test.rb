# frozen_string_literal: true

require "test_helper"

class DeleteMatchedTest < ActiveSupport::TestCase
  setup do
    @cache = nil
    @namespace = "test-#{SecureRandom.hex}"

    @cache = lookup_store(expires_in: 60)
    # @cache.logger = Logger.new($stdout)  # For test debugging

    # For LocalCacheBehavior tests
    @peek = lookup_store(expires_in: 60)
  end

  test "delete matched raises a NotImplementedError" do
    prefix = SecureRandom.alphanumeric
    assert_raises(NotImplementedError) { @cache.delete_matched("#{prefix}%") }
  end
end
