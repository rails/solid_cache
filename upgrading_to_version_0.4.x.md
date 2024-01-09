# Upgrading to version 0.4.x

The database schema has been updated from v0.4.0 onwards, so you'll need to follow the upgrade steps if you have used v0.3.x or lower.

## Why has the schema changed?

There are two new changes in v0.4.x.

1. Using a `key_hash` index instead of a `key` index. `key_hash` is a new 64 bit integer column derived from the SHA256 hash of the key.
   We'll store this value in the database and query by it. An index on a 64 bit integer is much more compact than one on a
   1K binary blob, so this will be easier for the database to keep in memory.
2. We'll store and index a new `byte_size` column. This stores the size of the row in bytes, and allow us to generate an estimate of
   the cache size by sampling the data.

## What will I need to do?

1. Update your app to use v0.4.x. This version will work with the old and new schemas
2. Follow the migration steps detailed below to update your schema
3. Now you should be good to upgrade to future versions

## Upgrade steps

1. Upgrade to gem version v0.4.x. At the same time set this in your config:

   ```
     config.solid_cache.key_hash_stage = :ignored
   ```

2. Install and run the first migration (AddKeyHashAndByteSizeToSolidCacheEntries)

   This adds the new columns.

3. Update your config

   ```
     config.solid_cache.key_hash_stage = :unindexed
   ```
   Now the application will be populating those columns.

4. Prepare the data

   We will be adding not null constraints and unique indexes in the following step so we need to make sure that there are no null
   values. The easiest thing to do here is to truncate the data if your app can handle restarting with a fresh cache.

   Otherwise you'll need to run a script to backfill the missing values.

5. Install and run the second migration (AddKeyHashAndByteSizeIndexesAndNullConstraintsToSolidCacheEntries)

   If you truncated the data in the previous step this should run quickly. If not and you have a large table it could take a while.

   If you have a process for online schema changes for large tables (pt-online-schema-change, gh-ost etc) you may need to use that here.

6. Update your config

   ```
     config.solid_cache.key_hash_stage = :indexed # this is the default so you can also remove it instead
   ```

   Now we will be querying the data by the new `key_hash` column

7. Install and run the final migration (RemoveKeyIndexFromSolidCacheEntries)

   This will remove the old index on `key`.

## Backfill script

The migration will be much easier if you truncate the cache, but if that's not possible this snippet should populate the missing columns:

```
def populate_key_hash_and_byte_size(from_id: nil, to_id: nil, batch_size: 1000, pause: 0)
  SolidCache::Entry.where(id: (from_id..to_id)).find_in_batches(batch_size: batch_size) do |entries|
    updates = entries.map { |entry| { key: entry.key, value: entry.value } }

    SolidCache::Entry.write_multi(updates)
    sleep pause unless pause.zero?

    puts "Updated to SolidCache::Entry##{entries.last.id}"
  end
end
```

## What if I am starting with v0.4.x?

If you are starting with v0.4.x or later you don't need to follow the upgrade steps. Install and apply all the migrations together and you
should be good to go.
