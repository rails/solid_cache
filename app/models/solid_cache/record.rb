module SolidCache
  class Record < ActiveRecord::Base
    NULL_INSTRUMENTER = ActiveSupport::Notifications::Instrumenter.new(ActiveSupport::Notifications::Fanout.new)

    self.abstract_class = true

    connects_to **SolidCache.connects_to if SolidCache.connects_to

    class << self
      def disable_instrumentation
        connection.with_instrumenter(NULL_INSTRUMENTER) do
          yield
        end
      end

      def with_shard(shard, &block)
        if shard && shard != Record.current_shard
          Record.connected_to(shard: shard, &block)
        else
          block.call
        end
      end
    end
  end
end

ActiveSupport.run_load_hooks :solid_cache, SolidCache::Record
