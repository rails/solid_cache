class SolidCache::InstallGenerator < Rails::Generators::Base
  class_option :skip_migrations,    type: :boolean, default: nil,
                                    desc: "Skip migrations"

  def add_rails_cache
    %w{development test production}.each do |env_name|
      if (env_config = Pathname(destination_root).join("config/environments/#{env_name}.rb")).exist?
        gsub_file env_config, /(# )?config\.cache_store = (:(?!null_store).*)/, "config.cache_store = :solid_cache_store"
      end
    end
  end

  def create_migrations
    unless options[:skip_migrations]
      rails_command "railties:install:migrations FROM=solid_cache", inline: true
    end
  end
end
