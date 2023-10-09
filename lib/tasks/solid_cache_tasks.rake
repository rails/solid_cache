desc "Copy over the migration, and set cache"
namespace :solid_cache do
  task :install, [:index] do |_t, args|
    args.with_defaults(index: 'btree')

    if args[:index] == 'btree' || args[:index] == 'hash'
       Rails::Command.invoke :generate, [ "solid_cache:install", "--index=#{args[:index]}" ]
    else
       abort "Invalid index type - only 'btree' and 'hash' are supported."
    end
  end
end
