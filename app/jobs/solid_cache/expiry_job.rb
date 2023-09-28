module SolidCache
  class ExpiryJob < ActiveJob::Base
    def perform(count, shard: nil, max_age:, max_entries:)
      Record.with_shard(shard) do
        Entry.expire(count, max_age: max_age, max_entries: max_entries)
      end
    end
  end
end
