# frozen_string_literal: true

require "test_helper"
require "generators/solid_cache/install/install_generator"

module SolidCache
  class SolidCache::InstallGeneratorTest < Rails::Generators::TestCase
    tests SolidCache::InstallGenerator

    destination File.expand_path("../../../../../tmp", __dir__)
    setup :prepare_destination

    setup do
      dummy_app_fixture = File.expand_path("../../../../fixtures/generators/dummy_app", __dir__)
      files = Dir.glob("#{dummy_app_fixture}/*")
      FileUtils.cp_r(files, destination_root)
      @old_schema_format = Rails.application.config.active_record.schema_format
    end

    teardown do
      Rails.application.config.active_record.schema_format = @old_schema_format
    end

    test "generator updates environment config" do
      run_generator
      assert_file "#{destination_root}/config/cache.yml", expected_cache_config
      assert_file "#{destination_root}/db/cache_schema.rb"
      assert_file "#{destination_root}/config/environments/development.rb", /config.cache_store = :memory_store\n/
      assert_file "#{destination_root}/config/environments/development.rb", /config.cache_store = :null_store\n/
      assert_file "#{destination_root}/config/environments/test.rb", /config.cache_store = :null_store\n/
      assert_file "#{destination_root}/config/environments/production.rb", /config.cache_store = :solid_cache_store\n/
    end

    test "generator creates SQL structure file when schema_format is sql" do
      Rails.application.config.active_record.schema_format = :sql

      run_generator

      assert_file "#{destination_root}/config/cache.yml", expected_cache_config
      assert_no_file "#{destination_root}/db/cache_schema.rb"

      # Check that a SQL structure file was created with database-specific syntax
      assert_file "#{destination_root}/db/cache_structure.sql" do |content|
        assert_match(/CREATE TABLE.*solid_cache_entries/, content)

        # Check for database-specific column types
        case ActiveRecord::Base.connection_db_config.adapter
        when "postgresql"
          assert_match(/key.*bytea/, content)
          assert_match(/value.*bytea/, content)
          assert_match(/key_hash.*bigint/, content)
          assert_match(/byte_size.*integer/, content)
        when "mysql2", "trilogy"
          assert_match(/key.*varbinary/, content)
          assert_match(/value.*longblob/, content)
          assert_match(/key_hash.*bigint/, content)
          assert_match(/byte_size.*int/, content)
        when "sqlite3"
          assert_match(/key.*blob/, content)
          assert_match(/value.*blob/, content)
          assert_match(/key_hash.*integer/, content)
          assert_match(/byte_size.*integer/, content)
        end

        assert_match(/index.*key_hash/, content)
      end

      assert_file "#{destination_root}/config/environments/production.rb", /config.cache_store = :solid_cache_store\n/
    end

    private
      def expected_cache_config
        <<~YAML
          default: &default
            database: cache
            store_options:
              # Cap age of oldest cache entry to fulfill retention policies
              # max_age: <%= 60.days.to_i %>
              max_size: <%= 256.megabytes %>
              namespace: <%= Rails.env %>

          development:
            <<: *default

          test:
            <<: *default

          production:
            <<: *default
        YAML
      end
  end
end
