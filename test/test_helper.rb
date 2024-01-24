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

class ActiveSupport::TestCase
  setup do
    SolidCache.each_shard do
      SolidCache::Entry.delete_all
    end
  end
end

def lookup_store(options = {})
  store_options = { namespace: @namespace }.merge(options)
  ActiveSupport::Cache.lookup_store(:solid_cache_store, store_options)
end

def send_entries_back_in_time(distance)
  @cache.primary_cluster.with_each_connection do
    SolidCache::Entry.uncached do
      SolidCache::Entry.all.each do |entry|
        entry.update_columns(created_at: entry.created_at - distance)
      end
    end
  end
end

def wait_for_background_tasks(cache, timeout: 2)
  timeout_at = Time.now + timeout
  threadpools = cache.clusters.map { |cluster| cluster.instance_variable_get("@background") }

  threadpools.each do |threadpool|
    loop do
      break if threadpool.completed_task_count == threadpool.scheduled_task_count
      raise "Timeout waiting for cache background tasks" if Time.now > timeout_at
      sleep 0.05
    end
  end
end

def uncached_entry_count
  SolidCache.each_shard.sum { SolidCache::Entry.uncached { SolidCache::Entry.count } }
end
