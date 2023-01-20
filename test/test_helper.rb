# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require_relative "../test/dummy/config/environment"
ActiveRecord::Migrator.migrations_paths = [File.expand_path("../test/dummy/db/migrate", __dir__)]
ActiveRecord::Migrator.migrations_paths << File.expand_path("../db/migrate", __dir__)
require "rails/test_help"
require "debug"

# Load fixtures from the engine
if ActiveSupport::TestCase.respond_to?(:fixture_path=)
  ActiveSupport::TestCase.fixture_path = File.expand_path("fixtures", __dir__)
  ActionDispatch::IntegrationTest.fixture_path = ActiveSupport::TestCase.fixture_path
  ActiveSupport::TestCase.file_fixture_path = ActiveSupport::TestCase.fixture_path + "/files"
  ActiveSupport::TestCase.fixtures :all
end

def lookup_store(options = {})
  ActiveSupport::Cache.lookup_store(:solid_cache_store, { namespace: @namespace }.merge(options))
end

def send_entries_back_in_time(distance)
  @cache.writing_all_shards do
    SolidCache::Entry.all.each do |entry|
      entry.update_columns(created_at: entry.created_at - distance, updated_at: entry.updated_at - distance)
    end
  end
end
