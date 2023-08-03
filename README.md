# SolidCache
SolidCache is a database backed ActiveSupport cache store implementation.

Using SQL databases backed by solid state storage we can have caches that are much larger and cheaper than traditional memory only Redis or Memcached backed caches.

Testing on HEY shows that reads and writes are 25%-50% slower than with a Redis cache. However this is not a significant percentage of the overall request time.

If cache misses are expensive (up to 50x the cost of a hit on HEY), then there are big advantages to caches that can hold months rather than days worth of data.

## Usage

To set solid cache as your Rails cache, you should add this to your environment config:

```ruby
config.cache_store = :solid_cache_store
```

SolidCache is a FIFO (first in, first out) cache. While this is not as efficient as an LRU cache, this is mitigated by the longer cache lifespans and it provides some advantages:

1. We don't need to track when items are read
2. We can estimate and control the cache size by comparing the maximum and minimum IDs.
3. By deleting from one end of the table and adding at the other end we can avoid fragmentation (on MySQL at least).

### Installation
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
```bash
$ bin/rails solid_cache:install:migrations
$ bin/rails db:migrate
```

### Configuration

#### Engine configuration

There are two options that can be set on the engine:

- `executor` - the [Rails executor](https://guides.rubyonrails.org/threading_and_code_execution.html#executor) used to wrap asynchronous operations, defaults to the app executor
- `connects_to` - a custom connects to value for the abstract `SolidCache::Record` active record model. Requires for sharding and/or using a separate cache database to the main app.

These can be set in your Rails configuration:

```ruby
Rails.application.configure do
  config.solid_cache.connects_to = {
    shards: {
      shard1: { writing: :cache_primary_shard1, reading: :cache_primary_shard1 },
      shard2: { writing: :cache_primary_shard1, reading: :cache_primary_shard1 }
    }
  }
end
```

#### Cache configuration

Solid cache supports these options in addition to the universal `ActiveSupport::Cache::Store` options.

- `error_handler` - a Proc to call to handle any `ActiveRecord::ActiveRecordError`s that are raises (default: log errors as warnings)
- `shards` - an Array of the database shards to connect to (shard connects_to must be configured separately via the SolidCache engine config)
- `trim_batch_size` - the batch size to use when deleting old records (default: `100`)
- `max_age` - the maximum age of entries in the cache (default: `2.weeks.to_i`)
- `max_entries` - the maximum number of entries allowed in the cache (default: `2.weeks.to_i`)

### Cache trimming

SolidCache tracks when we write to the cache. For every write it increments a counter by 1.25. Once the counter reaches the `trim_batch_size` it add a task to run on a cache trimming thread. That task will:

1. Check if we have exceeded the `max_entries` value (if set) by subtracting the max and min IDs from the `SolidCache::Entry` table (this is an estimate that ignores any gaps).
2. If we have it will delete 100 entries
3. If not it will delete up to 100 entries, provided they are all older than `max_age`.

Incrementing the counter by 1.25 per write allows us to trim the cache faster than we write to it if we need to.

Only triggering trimming when we write means that the if the cache is idle the background thread is also idle.

### Using a dedicated cache database

Add database configuration to database.yml, e.g.:

```
development
  cache:
    database: cache_development
    host: 127.0.0.1
    migrations_paths: "db/cache/migrate"
```

Create database:
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
$ mv db/migrate/*.solid_cache.rb db/cache/migrate
```

Set the engine configuration to point to the new database:
```
Rails.application.configure do
  config.solid_cache.connects_to = { database: { writing: :cache, reading: :cache } }
end
```

Run migrations:
```
$ bin/rails db:migrate
```

### Sharding the cache

SolidCache uses a consistant hashing scheme (copied from [the Redis ruby client](https://github.com/redis/redis-rb/blob/master/lib/redis/hash_ring.rb)) to shard the cache across multiple databases.

To implement this:

1. Add the configuration for the database shards to database.yml
2. Configure the shards via `config.solid_cache.connects_to`
3. Pass the shards for the cache to use via the shards option

For example:
```ruby
# config/database.yml
production:
  cache_shard1:
    database: cache1_production
    host: cache1-db
  cache_shard2:
    database: cache2_production
    host: cache2-db
  cache_shard3:
    database: cache3_production
    host: cache3-db


# config/environment/production.rb
Rails.application.configure do
  config.solid_cache.connects_to = {
    shards: {
      cache_shard1: { writing: :cache_shard1, reading: :cache_shard1 },
      cache_shard2: { writing: :cache_shard2, reading: :cache_shard2 },
      cache_shard3: { writing: :cache_shard3, reading: :cache_shard3 },
    }
  }

  config.cache_store = :solid_cache_store, shards: [ :cache_shard1, :cache_shard2, :cache_shard3 ]
end
```
### Enabling encryption

Add this to an initializer:

```ruby
ActiveSupport.on_load(:solid_cache_entry) do
  encrypts :value
end
```

## Contributing
Contribution directions go here.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
