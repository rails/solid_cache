module SolidCache
  class Record < ActiveRecord::Base
    self.abstract_class = true

    connects_to **SolidCache.connects_to if SolidCache.connects_to

    class << self
      def each_shard
        return to_enum(:each_shard) unless block_given?

        if (shards = SolidCache.connects_to[:shards]&.keys)
          shards.each do |shard|
            connected_to(shard: shard) { yield }
          end
        else
          yield
        end
      end
    end
  end
end

ActiveSupport.run_load_hooks :solid_cache, SolidCache::Record
