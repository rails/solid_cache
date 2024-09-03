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
    end

    test "generator updates environment config" do
      copy_database_config_fixture_to_destination_root "sqlite"
      run_generator [ "--skip-migrations" ]
      assert_file "#{destination_root}/config/solid_cache.yml", expected_solid_cache_config
      assert_file "#{destination_root}/config/environments/development.rb", /config.cache_store = :memory_store\n/
      assert_file "#{destination_root}/config/environments/development.rb", /config.cache_store = :null_store\n/
      assert_file "#{destination_root}/config/environments/test.rb", /config.cache_store = :null_store\n/
      assert_file "#{destination_root}/config/environments/production.rb", /config.cache_store = :solid_cache_store\n/
    end

    test "generator updates sqlite database config" do
      copy_database_config_fixture_to_destination_root "sqlite"
      run_generator [ "--skip-migrations" ]
      assert_file "#{destination_root}/config/database.yml", <<~YAML
        # SQLite. Versions 3.8.0 and up are supported.
        #   gem install sqlite3
        #
        #   Ensure the SQLite 3 gem is defined in your Gemfile
        #   gem "sqlite3"
        #
        default: &default
          adapter: sqlite3
          pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
          timeout: 5000

        development:
          <<: *default
          database: storage/development.sqlite3

        # Warning: The database defined as "test" will be erased and
        # re-generated from your development database when you run "rake".
        # Do not set this db to the same as development or production.
        test:
          <<: *default
          database: storage/test.sqlite3


        # Store production database in the storage/ directory, which by default
        # is mounted as a persistent Docker volume in config/deploy.yml.
        production:
          primary:
            <<: *default
            database: storage/production.sqlite3
          cache:
            <<: *default
            database: storage/production_cache.sqlite3
            migrations_paths: db/cache_migrate
      YAML
    end

    test "generator updates mysql database config" do
      copy_database_config_fixture_to_destination_root "mysql"
      run_generator [ "--skip-migrations" ]
      assert_file "#{destination_root}/config/database.yml", <<~YAML
        # MySQL. Versions 5.5.8 and up are supported.
        #
        # Install the MySQL driver
        #   gem install mysql2
        #
        # Ensure the MySQL gem is defined in your Gemfile
        #   gem "mysql2"
        #
        # And be sure to use new-style password hashing:
        #   https://dev.mysql.com/doc/refman/5.7/en/password-hashing.html
        #
        default: &default
          adapter: mysql2
          encoding: utf8mb4
          pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
          username: root
          password:
          host: <%= ENV.fetch("DB_HOST") { "127.0.0.1" } %>

        development:
          <<: *default
          database: bongo_development

        # Warning: The database defined as "test" will be erased and
        # re-generated from your development database when you run "rake".
        # Do not set this db to the same as development or production.
        test:
          <<: *default
          database: bongo_test

        # As with config/credentials.yml, you never want to store sensitive information,
        # like your database password, in your source code. If your source code is
        # ever seen by anyone, they now have access to your database.
        #
        # Instead, provide the password or a full connection URL as an environment
        # variable when you boot the app. For example:
        #
        #   DATABASE_URL="mysql2://myuser:mypass@localhost/somedatabase"
        #
        # If the connection URL is provided in the special DATABASE_URL environment
        # variable, Rails will automatically merge its configuration values on top of
        # the values provided in this file. Alternatively, you can specify a connection
        # URL environment variable explicitly:
        #
        #   production:
        #     url: <%= ENV["MY_APP_DATABASE_URL"] %>
        #
        # Read https://guides.rubyonrails.org/configuring.html#configuring-a-database
        # for a full overview on how database connection configuration can be specified.
        #
        production:
          primary: &production_primary
            <<: *default
            database: bongo_production
            username: bongo
            password: <%= ENV["BONGO_DATABASE_PASSWORD"] %>
          cache:
            <<: *production_primary
            database: bongo_production_cache
      YAML
    end

    private
      def expected_solid_cache_config
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

      def copy_database_config_fixture_to_destination_root(database)
        FileUtils.cp(File.expand_path("../../../../configs/#{database}-database.yml", __dir__), Pathname.new(destination_root).join("config/database.yml"))
      end

      def expected_mysql_database_config
      end
  end
end
