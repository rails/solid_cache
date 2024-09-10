# frozen_string_literal: true

# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require_relative "../test/dummy/config/environment"
ActiveRecord::Migrator.migrations_paths = [ File.expand_path("../test/dummy/db/migrate", __dir__) ]
ActiveRecord::Migrator.migrations_paths << File.expand_path("../db/migrate", __dir__)
require "rails/test_help"
require "debug"
require "mocha/minitest"

# Load fixtures from the engine
if ActiveSupport::TestCase.respond_to?(:fixture_paths=)
  ActiveSupport::TestCase.fixture_paths = [ File.expand_path("fixtures", __dir__) ]
  ActionDispatch::IntegrationTest.fixture_paths = ActiveSupport::TestCase.fixture_paths
  ActiveSupport::TestCase.file_fixture_path = ActiveSupport::TestCase.fixture_paths.first + "/files"
  ActiveSupport::TestCase.fixtures :all
end

ActiveSupport::TestCase.use_transactional_tests = false

if Rails::VERSION::MAJOR == 7 && Rails::VERSION::MINOR == 0 && SolidCache.configuration.connects_to
  SolidCache::Record.connecting_to(shard: SolidCache.configuration.shard_keys.first || :default)
end

class ActiveSupport::TestCase
  setup do
    @all_stores = []
    SolidCache::Record.each_shard do
      SolidCache::Entry.delete_all
    end
  end

  teardown do
    @all_stores.each do |store|
      wait_for_background_tasks(store)
    end
  end

  def lookup_store(options = {})
    store_options = { namespace: @namespace }.merge(options)
    ActiveSupport::Cache.lookup_store(:solid_cache_store, store_options).tap do |store|
      @all_stores << store
    end
  end

  def cleanup_stores
  end

  def send_entries_back_in_time(distance)
    @cache.with_each_connection do
      SolidCache::Entry.uncached do
        SolidCache::Entry.all.each do |entry|
          entry.update_columns(created_at: entry.created_at - distance)
        end
      end
    end
  end

  def wait_for_background_tasks(cache, timeout: 2)
    timeout_at = Time.now + timeout
    threadpool = cache.instance_variable_get("@background")

    loop do
      break if threadpool.completed_task_count == threadpool.scheduled_task_count
      raise "Timeout waiting for cache background tasks" if Time.now > timeout_at
      sleep 0.001
    end
  end

  def uncached_entry_count
    SolidCache::Record.each_shard.sum { SolidCache::Entry.uncached { SolidCache::Entry.count } }
  end

  def first_shard_key
    default_database? ? :default : SolidCache.configuration.shard_keys.first
  end

  def second_shard_key
    SolidCache.configuration.shard_keys.second
  end

  def single_database?
    [ "config/cache_database.yml", "config/cache_no_database.yml", "config/cache_unprepared_statements.yml" ].include?(ENV["SOLID_CACHE_CONFIG"])
  end

  def default_database?
    ENV["SOLID_CACHE_CONFIG"] == "config/cache_no_database.yml"
  end

  def shard_keys(cache, shard)
    namespaced_keys = 100.times.map { |i| @cache.send(:normalize_key, "key#{i}", {}) }
    shard_keys = cache.send(:connections).assign(namespaced_keys)[shard]
    shard_keys.map { |key| key.delete_prefix("#{@namespace}:") }
  end
end
