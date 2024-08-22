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
      run_generator [ "--skip-migrations" ]
      assert_file "#{destination_root}/config/solid_cache.yml", expected_config
      assert_file "#{destination_root}/config/environments/development.rb", /config.cache_store = :memory_store\n/
      assert_file "#{destination_root}/config/environments/development.rb", /config.cache_store = :null_store\n/
      assert_file "#{destination_root}/config/environments/test.rb", /config.cache_store = :null_store\n/
      assert_file "#{destination_root}/config/environments/production.rb", /config.cache_store = :solid_cache_store\n/
    end

    private
      def expected_config
        <<~YAML
          default: &default
            database: cache
            store_options:
              max_age: <%= 1.week.to_i %>
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
