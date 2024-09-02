# frozen_string_literal: true

class SolidCache::InstallGenerator < Rails::Generators::Base
  source_root File.expand_path("templates", __dir__)

  def add_rails_cache
    if (env_config = app_root.join("config/environments/production.rb")).exist?
      gsub_file env_config, /(# )?config\.cache_store = (:.*)/, "config.cache_store = :solid_cache_store"
    end
  end

  def create_config_solid_cache_yml
    template "config/solid_cache.yml"
  end

  def add_cache_db_to_database_yml
    if app_root.join("config/database.yml").exist?
      if app_is_using_sqlite?
        gsub_file database_yml, /production:\s*<<: \*default.*/m, sqlite_database_config_with_cache
      else
        gsub_file database_yml, /production:\s*<<: \*default.*/m, generic_database_config_with_cache
      end
    end
  end

  def create_migrations
    rails_command "railties:install:migrations DATABASE=cache FROM=solid_cache", inline: true
  end

  private
    def app_root
      Pathname.new(destination_root)
    end

    def database_yml
      app_root.join("config/database.yml")
    end

    def app_is_using_sqlite?
      database_yml.read.match?(/production:.*sqlite3/m)
    end

    def sqlite_database_config_with_cache
      <<~YAML
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

    def app_name_from_production_database_name
      database_yml.read.scan(/database: (\w+)_production/).flatten.first
    end

    def generic_database_config_with_cache
      app_name = app_name_from_production_database_name

      <<~YAML
production:
  primary: &production_primary
    <<: *default
    database: #{app_name}_production
    username: #{app_name}
    password: <%= ENV["#{app_name.upcase}_DATABASE_PASSWORD"] %>
  cache:
    <<: *production_primary
    database: #{app_name}_production_cache
      YAML
    end
end
