require "test_helper"

class ActiveSupport::DatabaseCacheTest < ActiveSupport::TestCase
  test "it has a version number" do
    assert ActiveSupport::DatabaseCache::VERSION
  end
end
