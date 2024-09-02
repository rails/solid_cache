# frozen_string_literal: true

module CacheInstrumentationBehavior
  def test_write_multi_instrumentation
    key_1 = SecureRandom.uuid
    key_2 = SecureRandom.uuid
    value_1 = SecureRandom.alphanumeric
    value_2 = SecureRandom.alphanumeric
    writes = { key_1 => value_1, key_2 => value_2 }

    events = with_instrumentation "write_multi" do
      @cache.write_multi(writes)
    end

    assert_equal %w[ cache_write_multi.active_support ], events.map(&:name)
    assert_nil events[0].payload[:super_operation]
    assert_equal({ key_1 => value_1, key_2 => value_2 }, events[0].payload[:key])
  end

  def test_instrumentation_with_fetch_multi_as_super_operation
    key_1 = SecureRandom.uuid
    @cache.write(key_1, SecureRandom.alphanumeric)

    key_2 = SecureRandom.uuid

    events = with_instrumentation "read_multi" do
      @cache.fetch_multi(key_2, key_1) { |key| key * 2 }
    end

    assert_equal %w[ cache_read_multi.active_support ], events.map(&:name)
    assert_equal :fetch_multi, events[0].payload[:super_operation]
    assert_equal [key_2, key_1], events[0].payload[:key]
    assert_equal [key_1], events[0].payload[:hits]
    assert_equal @cache.class.name, events[0].payload[:store]
  end

  def test_fetch_multi_instrumentation_order_of_operations
    skip if Rails::VERSION::MAJOR == 7 && Rails::VERSION::MINOR < 2
    operations = []
    callback = ->(name, *) { operations << name }

    key_1 = SecureRandom.uuid
    key_2 = SecureRandom.uuid

    ActiveSupport::Notifications.subscribed(callback, /^cache_(read_multi|write_multi)\.active_support$/) do
      @cache.fetch_multi(key_1, key_2) { |key| key * 2 }
    end

    assert_equal %w[ cache_read_multi.active_support cache_write_multi.active_support ], operations
  end

  def test_read_multi_instrumentation
    key_1 = SecureRandom.uuid
    @cache.write(key_1, SecureRandom.alphanumeric)

    key_2 = SecureRandom.uuid

    events = with_instrumentation "read_multi" do
      @cache.read_multi(key_2, key_1)
    end

    assert_equal %w[ cache_read_multi.active_support ], events.map(&:name)
    assert_equal [key_2, key_1], events[0].payload[:key]
    assert_equal [key_1], events[0].payload[:hits]
    assert_equal @cache.class.name, events[0].payload[:store]
  end

  private
    def with_instrumentation(method)
      event_name = "cache_#{method}.active_support"

      [].tap do |events|
        ActiveSupport::Notifications.subscribe(event_name) { |event| events << event }
        yield
      end
    ensure
      ActiveSupport::Notifications.unsubscribe event_name
    end
end
