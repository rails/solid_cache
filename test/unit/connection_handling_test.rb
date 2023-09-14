require "test_helper"
require "active_support/testing/method_call_assertions"

class SolidCache::TrimmingTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @namespace = "test-#{SecureRandom.hex}"
  end

  def test_active_record_instrumention
    instrumented_cache = lookup_store
    uninstrumented_cache = lookup_store(active_record_instrumentation: false)

    calls = 0
    callback = ->(*args) { calls += 1 }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      assert_changes -> { calls } do
        instrumented_cache.read("foo")
      end
      assert_changes -> { calls } do
        instrumented_cache.write("foo", "bar")
      end
      assert_no_changes -> { calls } do
        uninstrumented_cache.read("foo")
      end
      assert_no_changes -> { calls } do
        uninstrumented_cache.write("foo", "bar")
      end
    end
  end
end
