require "test_helper"
require "generators/solid_cache/install/install_generator"

module SolidCache
  class SolidCache::InstallGeneratorTest < Rails::Generators::TestCase
    tests SolidCache::InstallGenerator

    destination File.expand_path("../../../../fixtures/tmp", __dir__)
    setup :prepare_destination

    setup do
      dummy_app_fixture = File.expand_path("../../../../fixtures/generators/dummy_app", __dir__)
      files = Dir.glob("#{dummy_app_fixture}/*")
      FileUtils.cp_r(files, destination_root)
    end

    test "generator updates environment config" do
      run_generator ["--skip-migrations"]
      assert_file "#{destination_root}/config/environments/development.rb", /config.cache_store = :solid_cache_store\n/
      assert_file "#{destination_root}/config/environments/development.rb", /config.cache_store = :null_store\n/
      assert_file "#{destination_root}/config/environments/test.rb", /config.cache_store = :null_store\n/
      assert_file "#{destination_root}/config/environments/production.rb", /config.cache_store = :solid_cache_store\n/
    end
  end
end
