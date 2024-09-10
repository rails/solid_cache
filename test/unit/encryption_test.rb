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

  private
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
