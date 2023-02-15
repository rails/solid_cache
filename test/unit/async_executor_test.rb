require "test_helper"
require "active_support/testing/method_call_assertions"

class SolidCache::AsyncExecutorTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @cache = nil
    @namespace = "test-#{SecureRandom.hex}"

    @cache = lookup_store(trim_batch_size: 2, shards: nil)
  end

  def test_async_errors_are_reported
    error_subscriber = ErrorSubscriber.new
    Rails.error.subscribe(error_subscriber)

    @cache.send(:async) do
      raise "Boom!"
    end

    sleep 0.1

    assert_equal 1, error_subscriber.errors.count
    assert_equal "Boom!", error_subscriber.errors.first[0].message
    assert_equal({context: {}, handled: false, level: :error, source: nil}, error_subscriber.errors.first[1])
  ensure
    Rails.error.unsubscribe(error_subscriber) if Rails.error.respond_to?(:unsubscribe)
  end

  class ErrorSubscriber
    attr_reader :errors

    def initialize
      @errors = []
    end

    def report(error, handled:, severity:, context:, source: nil)
      errors << [error, { context: context, handled: handled, level: severity, source: source }]
    end
  end
end
