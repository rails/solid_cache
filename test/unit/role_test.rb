require "test_helper"

class RoleTest < ActiveSupport::TestCase
  test "can't write to reading role" do
    cache = lookup_store(expires_in: 60, writing_role: :reading)
    assert_raises(ActiveRecord::ReadOnlyError) do
      cache.write("foo", 1)
    end
  end

  test "can read from the writing role" do
    cache = lookup_store(expires_in: 60, reading_role: :writing)
    assert_nil cache.read("foo")
  end

  test "can set roles to the same" do
    cache = lookup_store(expires_in: 60, role: :writing)
    assert_nil cache.read("foo")
    cache.write("foo", 1)
    assert_equal 1, cache.read("foo")
  end
end
