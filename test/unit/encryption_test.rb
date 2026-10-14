# frozen_string_literal: true

require "test_helper"

class SolidCache::EncryptionTest < ActiveSupport::TestCase
  setup do
    @cache = lookup_store
    @shard_key = shard_keys(@cache, first_shard_key).first
  end

  test "not encrypted" do
    skip if ENV["SOLID_CACHE_CONFIG"] =~ /config\/cache_encrypted.*\.yml/

    @cache.write(@shard_key, "value")
    assert_not_nil first_value
    assert_equal raw_first_value, first_value
  end

  test "encrypted with defaults" do
    skip unless ENV["SOLID_CACHE_CONFIG"] == "config/cache_encrypted.yml"

    @cache.write(@shard_key, "value")
    assert_not_nil first_value
    assert_not_equal raw_first_value, first_value
    message = ActiveSupport::MessagePack.load(raw_first_value)
    assert_not_nil message["p"]
    assert_not_nil message["h"]
  end

  test "encrypted with custom settings" do
    skip unless ENV["SOLID_CACHE_CONFIG"] == "config/cache_encrypted_custom.yml"

    @cache.write(@shard_key, "value")
    assert_not_nil first_value
    assert_not_equal raw_first_value, first_value
    message = JSON.parse(raw_first_value)
    assert_not_nil message["p"]
    assert_not_nil message["h"]
  end

  [ :rotated_key, :plaintext ].each do |scenario|
    test "read treats unreadable entries as misses (#{scenario})" do
      skip unless SolidCache.configuration.encrypt?

      @cache.write(@shard_key, "value")
      make_unreadable(@shard_key, scenario)

      report = assert_error_reported(ActiveRecord::Encryption::Errors::Decryption) do
        assert_nil @cache.read(@shard_key)
      end
      assert_predicate report, :handled?
      assert_equal :warning, report.severity
    end

    test "read multi preserves readable entries (#{scenario})" do
      skip unless SolidCache.configuration.encrypt?

      other_key = shard_keys(@cache, first_shard_key).second
      @cache.write(@shard_key, "unreadable")
      @cache.write(other_key, "readable")
      make_unreadable(@shard_key, scenario)

      assert_error_reported(ActiveRecord::Encryption::Errors::Decryption) do
        assert_equal({ other_key => "readable" }, @cache.read_multi(@shard_key, other_key))
      end
    end

    test "fetch replaces unreadable entries (#{scenario})" do
      skip unless SolidCache.configuration.encrypt?

      @cache.write(@shard_key, "value")
      make_unreadable(@shard_key, scenario)

      assert_error_reported(ActiveRecord::Encryption::Errors::Decryption) do
        assert_equal "replacement", @cache.fetch(@shard_key) { "replacement" }
      end
      assert_no_error_reported { assert_equal "replacement", @cache.read(@shard_key) }
    end

    test "expiry rebuilds unreadable size estimates and expires old entries (#{scenario})" do
      skip unless SolidCache.configuration.encrypt?

      estimates_key = SolidCache::Entry::Size::MovingAverageEstimate::ESTIMATES_KEY
      SolidCache::Entry.write(@shard_key, "value")
      SolidCache::Entry.write(estimates_key, "1000000000")
      make_unreadable(@shard_key, scenario)
      make_unreadable(estimates_key, scenario)
      SolidCache::Entry.where(key: @shard_key).update_all(created_at: 3.weeks.ago)
      expected_size = SolidCache::Entry.sum(:byte_size)

      assert_error_reported(ActiveRecord::Encryption::Errors::Decryption) do
        SolidCache::Entry.expire(10, max_age: 2.weeks, max_entries: nil, max_size: 1.megabyte)
      end
      assert_not SolidCache::Entry.exists?(key: @shard_key)
      assert_no_error_reported do
        assert_equal expected_size.to_s, SolidCache::Entry.read(estimates_key)
      end
    end
  end

  private
    def make_unreadable(key, scenario)
      value = SolidCache::Entry.find_by!(key: key).value
      if scenario == :rotated_key
        key_provider = ActiveRecord::Encryption::EnvelopeEncryptionKeyProvider.new
        key_provider.stubs(:active_primary_key).returns(
          ActiveRecord::Encryption::DerivedSecretKeyProvider.new("old cache key").encryption_key
        )
        context = SolidCache.configuration.encryption_context_properties.merge(
          key_provider: key_provider
        )
        value = ActiveRecord::Encryption.with_encryption_context(context) do
          ActiveRecord::Encryption.encryptor.encrypt(value)
        end
      end

      quoted_value = SolidCache::Entry.connection.quote(ActiveRecord::Type::Binary::Data.new(value))
      SolidCache::Entry.where(key: key).update_all(value: Arel.sql(quoted_value))
    end

    def raw_first_value
      raw = SolidCache::Entry.connection.select_all("select * from solid_cache_entries order by id desc limit 1").first["value"]

      if ActiveRecord::Base.connection.adapter_name == "PostgreSQL"
        ActiveRecord::Base.connection.unescape_bytea(raw)
      else
        raw
      end
    end

    def first_value
      SolidCache::Entry.first.value
    end
end
