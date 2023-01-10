# ActiveSupport::DatabaseCache
Short description and motivation.

## Usage
How to use my plugin.

## Installation
Add this line to your application's Gemfile:

```ruby
gem "active_support-database_cache"
```

And then execute:
```bash
$ bundle
```

Or install it yourself as:
```bash
$ gem install active_support-database_cache
```

Adding the cache to your main database:

```bash
$ bin/rails active_support-database_cache:install:migrations
```

Install and run migrations:
```
$ bin/rails active_support_database_cache:install:migrations
$ bin/rails db:migrate
```

# Adding the cache to a separate database

Add database configuration to database.yml.

Create database
```
$ bin/rails db:create
```

Install migrations:
```
$ bin/rails active_support_database_cache:install:migrations
```

Move migrations to custom migrations folder:
```
$ mkdir -p db/cache/migrate
$ mv db/migration/*_create_active_support_database_cache_entries.active_support_database_cache.rb db/cache/migrate
```

Add an initializer to point models at the new database
```
# config/active_storage_database_cache.rb
ActiveSupport.on_load(:active_storage_database_cache) do
  connects_to database: { writing: :cache_primary, reading: :cache_replica }
end
```

Run migrations:
```
$ bin/rails db:migrate
```

## Contributing
Contribution directions go here.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
