# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require_relative "../test/dummy/config/environment"
ActiveRecord::Migrator.migrations_paths = [File.expand_path("../test/dummy/db/migrate", __dir__)]
ActiveRecord::Migrator.migrations_paths << File.expand_path("../db/migrate", __dir__)
require "rails/test_help"
require "debug"
require "mocha/minitest"
require "database_cleaner/active_record"

# Load fixtures from the engine
if ActiveSupport::TestCase.respond_to?(:fixture_path=)
  ActiveSupport::TestCase.fixture_path = File.expand_path("fixtures", __dir__)
  ActionDispatch::IntegrationTest.fixture_path = ActiveSupport::TestCase.fixture_path
  ActiveSupport::TestCase.file_fixture_path = ActiveSupport::TestCase.fixture_path + "/files"
  ActiveSupport::TestCase.fixtures :all
end

ActiveSupport::TestCase.use_transactional_tests = false

DatabaseCleaner.strategy = :truncation
DatabaseCleaner::ActiveRecord.config_file_location = Rails.root.join("config/database.yml")

DatabaseCleaner[:active_record, db: :primary_shard_one].strategy = :truncation
DatabaseCleaner[:active_record, db: :primary_shard_two].strategy = :truncation
DatabaseCleaner[:active_record, db: :secondary_shard_one].strategy = :truncation
DatabaseCleaner[:active_record, db: :secondary_shard_two].strategy = :truncation

class ActiveSupport::TestCase
  setup do
    DatabaseCleaner.clean
  end
end

def lookup_store(options = {})
  store_options = { namespace: @namespace }.merge(options)
  store_options.merge!(cluster: { shards: [:default] }) unless store_options.key?(:cluster) || store_options.key?(:clusters)
  ActiveSupport::Cache.lookup_store(:solid_cache_store, store_options)
end

def send_entries_back_in_time(distance)
  @cache.primary_cluster.with_each_shard do
    SolidCache::Entry.all.each do |entry|
      entry.update_columns(created_at: entry.created_at - distance)
    end
  end
end
