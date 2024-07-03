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
  rescue Exception
    errors << task
  end

  abort "Errors running #{errors.join(', ')}" if errors.any?
end

def configs
  [ :default, :connects_to, :database, :no_database, :shards, :unprepared_statements ]
end

task :test do
  tasks = configs.map { |config| "test:#{config}" }
  run_without_aborting(*tasks)
end

configs.each do |config|
  namespace :test do
    task config do
      if config == :default
        sh("bin/rails test")
      else
        sh("SOLID_CACHE_CONFIG=config/solid_cache_#{config}.yml bin/rails test")
      end
    end
  end
end
