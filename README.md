# SolidCache
Short description and motivation.

## Usage
How to use my plugin.

## Installation
Add this line to your application's Gemfile:

```ruby
gem "solid_cache"
```

And then execute:
```bash
$ bundle
```

Or install it yourself as:
```bash
$ gem install solid_cache
```

Adding the cache to your main database:

```bash
$ bin/rails solid_cache:install:migrations
```

Install and run migrations:
```
$ bin/rails solid_cache:install:migrations
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
$ bin/rails solid_cache:install:migrations
```

Move migrations to custom migrations folder:
```
$ mkdir -p db/cache/migrate
$ mv db/migration/*_create_solid_cache_entries.solid_cache.rb db/cache/migrate
```

Add an initializer to point models at the new database
```
# config/solid_cache.rb
ActiveSupport.on_load(:solid_cache) do
  connects_to database: { writing: :cache_primary, reading: :cache_replica }
end
```

Run migrations:
```
$ bin/rails db:migrate
```

# Enabling encryption

Add this to an initializer:

```
ActiveSupport.on_load(:solid_cache_entry) do
  encrypts :value
end
```

## Contributing
Contribution directions go here.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
