# frozen_string_literal: true

class SolidCache::InstallGenerator < Rails::Generators::Base
  source_root File.expand_path("templates", __dir__)

  def add_rails_cache
    gsub_file app_root.join("config/environments/production.rb"),
      /(# )?config\.cache_store = (:.*)/, "config.cache_store = :solid_cache_store"
  end

  def create_config_solid_cache_yml
    template "config/solid_cache.yml"
  end

  def add_cache_db_to_database_yml
    if two_tier_production_configuration?
      append_cache_db_to_two_tier_configuration
    elsif three_tier_production_configuration?
      append_cache_db_to_three_tier_configuration
    else
      append_configuration_comment
    end
  end

  def add_solid_cache_db_schema
    template "db/cache_schema.rb"
  end

  private
    def app_root
      Pathname.new(destination_root)
    end

    def database_yml
      app_root.join("config/database.yml")
    end

    def database_config
      @database_config ||= YAML.load(database_yml.read, aliases: true)
    end

    def production_block
      return @production_block if defined? @production_block

      production_block_regex = %r{
        \nproduction:    # Match 'production:' at the start of a line
        (?:              # Start of non-capturing group for block
          \n             # Match newline
          (?:            # Start of another non-capturing group for lines
            [ \t]+.*     # Match indented lines (one or more spaces/tabs, then any content)
            |            # OR
            [ \t]*       # Match blank lines (any number of spaces/tabs, including none)
          )
        )*               # End of outer group, repeat 0 or more times
      }x
      @production_block = database_yml.read[production_block_regex]
    end

    def deconstruct_production_block
      newline, name, *contents = production_block.split "\n"
      indentation = contents.first[/^([ \t]*)\S/, 1]

      [indentation, newline, name, *contents]
    end

    def two_tier_production_configuration?
      database_config["production"].key?("adapter")
    end

    def append_cache_db_to_two_tier_configuration
      indentation, newline, name, *contents = deconstruct_production_block
      app_name = app_name_from_production_database_name

      if database_config.dig("production", "adapter") == "sqlite3"
        output = [
          newline,
          name,
          "#{indentation}primary:",
          *contents.map { |it| "#{indentation * 2}#{it.strip}" },
          "#{indentation}cache:",
          "#{indentation * 2}<<: *default",
          "#{indentation * 2}database: storage/production_cache.sqlite3",
          "#{indentation * 2}migrations_paths: db/cache_migrate",
          ""
        ]
      else
        output = [
          newline,
          name,
          "#{indentation}primary: &production_primary",
          *contents.map { |it| "#{indentation * 2}#{it}" },
          "#{indentation}cache:",
          "#{indentation * 2}<<: *production_primary",
          "#{indentation * 2}database: #{app_name}_production_cache",
          ""
        ]
      end

      gsub_file database_yml, production_block, output.join("\n")
    end

    def three_tier_production_configuration?
      database_config["production"].key?("primary")
    end

    def append_cache_db_to_three_tier_configuration
      return if database_config["production"].key?("cache")

      indentation, newline, name, *contents = deconstruct_production_block
      app_name = app_name_from_production_database_name

      if database_config.dig("production", "primary", "adapter") == "sqlite3"
        output = [
          newline,
          name,
          *contents,
          "#{indentation}cache:",
          "#{indentation * 2}<<: *default",
          "#{indentation * 2}database: storage/production_cache.sqlite3",
          "#{indentation * 2}migrations_paths: db/cache_migrate",
          ""
        ]
      else
        primary = contents.find { |it| it.match?(/^([ \t]*)primary:.*$/) }
        primary_alias = primary[/primary:\s*&([^ \t]*)/, 1] || "default"

        output = [
          newline,
          name,
          *contents,
          "#{indentation}cache:",
          "#{indentation * 2}<<: *#{primary_alias}",
          "#{indentation * 2}database: #{app_name}_production_cache",
          ""
        ]
      end

      gsub_file database_yml, production_block, output.join("\n")
    end

    def append_configuration_comment
      app_name = app_name_from_production_database_name

      append_to_file "config/database.yml", <<~TEXT
        # You need to add the following configuration to your production environment configuration:
        #
      TEXT
      if database_yml.read.include?("adapter: sqlite3")
        append_to_file "config/database.yml", <<~TEXT
          # cache:
          #   <<: *default
          #   database: storage/production_cache.sqlite3
          #   migrations_paths: db/cache_migrate
        TEXT
      else
        append_to_file "config/database.yml", <<~TEXT
          # cache:
          #   <<: *production_primary
          #   database: #{app_name}_production_cache
        TEXT
      end
    end

    def app_name_from_production_database_name
      database_yml.read.scan(/database: (\w+)_production/).flatten.first
    end
end
