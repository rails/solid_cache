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

  test "deletes keys matching glob" do
    prefix = SecureRandom.alphanumeric
    key = "#{prefix}#{SecureRandom.uuid}"
    @cache.write(key, "bar")

    other_key = SecureRandom.uuid
    @cache.write(other_key, SecureRandom.alphanumeric)
    @cache.delete_matched("#{prefix}%")
    assert_not @cache.exist?(key)
    assert @cache.exist?(other_key)
  end

  test "deletes exact key" do
    prefix = SecureRandom.alphanumeric
    key = "#{prefix}#{SecureRandom.uuid}"
    @cache.write(key, "bar")

    other_key = SecureRandom.uuid
    @cache.write(other_key, SecureRandom.alphanumeric)
    @cache.delete_matched(key)
    assert_not @cache.exist?(key)
    assert @cache.exist?(other_key)
  end

  test "deletes when more items than batch size" do
    prefix = SecureRandom.alphanumeric

    keys = 5.times.map { "#{prefix}#{SecureRandom.uuid}" }
    keys.each { |key| @cache.write(key, "bar") }

    other_key = SecureRandom.uuid
    @cache.write(other_key, SecureRandom.alphanumeric)

    @cache.delete_matched("#{prefix}%", batch_size: 2)
    keys.each { |key| assert_not @cache.exist?(key) }

    assert @cache.exist?(other_key)
  end

  test "fails when starts with %" do
    assert_raise ArgumentError do
      @cache.delete_matched("%foo")
    end
  end

  test "fails when starts with _" do
    assert_raise ArgumentError do
      @cache.delete_matched("_foo")
    end
  end

  test "fails with regexp matchers" do
    assert_raise ArgumentError do
      @cache.delete_matched(/OO/i)
    end
  end
end
