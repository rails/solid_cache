# frozen_string_literal: true

require "test_helper"

class RailsCacheTest < ActiveSupport::TestCase
  test "reads cache yml config" do
    assert_equal 3600, Rails.cache.max_age
  end
end
