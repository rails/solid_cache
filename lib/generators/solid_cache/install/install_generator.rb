# frozen_string_literal: true

class SolidCache::InstallGenerator < Rails::Generators::Base
  source_root File.expand_path("templates", __dir__)

  def copy_files
    template "config/cache.yml"
    template "db/cache_schema.rb"
  end

  def configure_cache_store_adapter
    gsub_file Pathname.new(destination_root).join("config/environments/production.rb"),
      /(# )?config\.cache_store = (:.*)/, "config.cache_store = :solid_cache_store"
  end
end
