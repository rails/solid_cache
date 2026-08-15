# frozen_string_literal: true

require "test_helper"

class SolidCacheFailsafeErrorsTest < ActiveSupport::TestCase
  setup do
    @namespace = "test-#{SecureRandom.hex}"
  end

  # ActiveRecord::ConnectionFailed is raised when the server drops the connection
  # mid-query (e.g. Postgres idle_in_transaction_session_timeout, MySQL server
  # gone away). It is a StatementInvalid, not a ConnectionNotEstablished, so it
  # must be listed explicitly to degrade to a cache miss like other transient
  # connection failures. SolidCacheConnectionFailedFailsafeTest covers the
  # degrading of every cache operation; these cover the error handler contract.
  def test_connection_failed_is_passed_to_the_error_handler
    handled = []
    handler = ->(method:, returning:, exception:) { handled << [ returning, exception ] }

    emulating_errors(ActiveRecord::ConnectionFailed) do
      lookup_store(namespace: @namespace, error_handler: handler).read("key")
    end

    returning, exception = handled.first
    assert_nil returning
    assert_instance_of ActiveRecord::ConnectionFailed, exception
  end

  def test_connection_failed_is_raised_when_the_error_handler_raises
    cache = lookup_store(namespace: @namespace, error_handler: ->(method:, returning:, exception:) { raise exception })

    assert_raise ActiveRecord::ConnectionFailed do
      emulating_errors(ActiveRecord::ConnectionFailed) { cache.read("key") }
    end
  end

  # The failsafe only rescues transient errors so that misconfiguration and
  # bugs are not silently turned into cache misses (see #182).
  def test_non_transient_errors_are_not_swallowed
    [ ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError ].each do |error|
      assert_raise error, "#{error} should propagate" do
        emulating_errors(error) { lookup_store(namespace: @namespace).read("key") }
      end
    end
  end
end
