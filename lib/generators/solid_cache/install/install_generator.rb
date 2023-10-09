require "rails/generators/active_record"

class SolidCache::InstallGenerator < Rails::Generators::Base
  include ActiveRecord::Generators::Migration

  source_root File.expand_path("templates", __dir__)
  class_option :skip_migrations,    type: :boolean, default: nil, desc: "Skip migrations"
  class_option :index,             type: :string, default: "btree", desc: "Index type for key column"

  def add_rails_cache
    %w[development test production].each do |env_name|
      if (env_config = Pathname(destination_root).join("config/environments/#{env_name}.rb")).exist?
        gsub_file env_config, /(# )?config\.cache_store = (:(?!null_store).*)/, "config.cache_store = :solid_cache_store"
      end
    end
  end

  def create_migrations
    return if options[:skip_migrations]

    case options[:index]
    when "btree"
      migration_template "create_solid_cache_entries_btree.rb", "db/migrate/create_solid_cache_entries.rb"
    when "hash"
      migration_template "create_solid_cache_entries_hash.rb", "db/migrate/create_solid_cache_entries.rb"
    end
  end
end
