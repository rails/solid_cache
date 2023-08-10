require "test_helper"
require_relative "behaviors"
require "active_support/testing/method_call_assertions"

class SolidCacheTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::MethodCallAssertions
  include CacheStoreBehavior
  include CacheStoreVersionBehavior
  include CacheStoreCoderBehavior
  include LocalCacheBehavior
  include CacheIncrementDecrementBehavior
  include CacheInstrumentationBehavior
  include EncodedKeyCacheBehavior

  setup do
    @cache = nil
    @namespace = "test-#{SecureRandom.hex}"

    @cache = lookup_store(expires_in: 60)
    # @cache.logger = Logger.new($stdout)  # For test debugging

    # For LocalCacheBehavior tests
    @peek = lookup_store(expires_in: 60)
  end

  test "each_shard" do
    shards = SolidCache.each_shard.map { SolidCache::Record.current_shard }
    assert_equal [ :default, :default2, :primary_shard_one, :primary_shard_two, :secondary_shard_one, :secondary_shard_two ], shards
  end

  test "shard_databases" do
    configs = SolidCache::Record.configurations
    shard_names = [:default, :default2, :primary_shard_one, :primary_shard_two, :secondary_shard_one, :secondary_shard_two]
    expected = shard_names.to_h do |shard_name|
      database_name = SolidCache.connects_to.dig(:shards, shard_name, :writing).to_s
      config = configs.configs_for(env_name: Rails.env, name: database_name)
      destination = [ config.try(:host), config.try(:port), config.try(:database) ].compact.join("-")
      [ shard_name, destination ]
    end

    assert_equal expected, SolidCache.shard_destinations
  end
end

class SolidCacheFailsafeTest < ActiveSupport::TestCase
  include FailureSafetyBehavior

  setup do
    @cache = nil
    @namespace = "test-#{SecureRandom.hex}"

    @cache = lookup_store(expires_in: 60)
    # @cache.logger = Logger.new($stdout)  # For test debugging

    # For LocalCacheBehavior tests
    @peek = lookup_store(expires_in: 60)
  end

  def emulating_unavailability
    stub_matcher = ActiveRecord::Base.connection.class.any_instance
    stub_matcher.stubs(:exec_query).raises(ActiveRecord::StatementInvalid)
    stub_matcher.stubs(:exec_delete).raises(ActiveRecord::StatementInvalid)
    yield ActiveSupport::Cache::SolidCacheStore.new(namespace: @namespace)
  ensure
    stub_matcher.unstub(:exec_query)
    stub_matcher.unstub(:exec_delete)
  end
end

class SolidCacheRaisingTest < ActiveSupport::TestCase
  include FailureRaisingBehavior

  setup do
    @cache = nil
    @namespace = "test-#{SecureRandom.hex}"

    @cache = lookup_store(expires_in: 60)
    # @cache.logger = Logger.new($stdout)  # For test debugging

    # For LocalCacheBehavior tests
    @peek = lookup_store(expires_in: 60)
  end

  def emulating_unavailability
    stub_matcher = ActiveRecord::Base.connection.class.any_instance
    stub_matcher.stubs(:exec_query).raises(ActiveRecord::StatementInvalid)
    stub_matcher.stubs(:exec_delete).raises(ActiveRecord::StatementInvalid)
    yield ActiveSupport::Cache::SolidCacheStore.new(namespace: @namespace,
      error_handler: -> (method:, returning:, exception:) { raise exception })
  ensure
    stub_matcher.unstub(:exec_query)
    stub_matcher.unstub(:exec_delete)
  end
end
