# frozen_string_literal: true

desc "Copy over the migration, and set cache"
namespace :solid_cache do
  task :install do
    Rails::Command.invoke :generate, [ "solid_cache:install" ]
  end
end
