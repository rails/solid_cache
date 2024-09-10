# frozen_string_literal: true

require "bundler/setup"

APP_RAKEFILE = File.expand_path("test/dummy/Rakefile", __dir__)
load "rails/tasks/engine.rake"

load "rails/tasks/statistics.rake"

require "bundler/gem_tasks"
require "rake/testtask"

def run_without_aborting(*tasks)
  errors = []

  tasks.each do |task|
    Rake::Task[task].invoke
  rescue Exception => e
    puts e.message
    puts e.backtrace
    errors << task
  end

  abort "Errors running #{errors.join(', ')}" if errors.any?
end

def configs
  [ :default, :connects_to, :database, :encrypted, :encrypted_custom, :no_database, :shards, :unprepared_statements ]
end

task :test do
  tasks = configs.map { |config| "test:#{config}" }
  run_without_aborting(*tasks)
end

configs.each do |config|
  namespace :test do
    task config do
      if config.to_s.start_with?("encrypted") && ENV["TARGET_DB"] == "postgres" && Rails::VERSION::MAJOR <= 7
        puts "Skipping encrypted tests on PostgreSQL as binary encrypted columns are not supported by Rails yet"
        next
      end

      if config == :default
        sh("bin/rails test")
      else
        sh("SOLID_CACHE_CONFIG=config/cache_#{config}.yml bin/rails test")
      end
    end
  end
end

task default: [:test]
