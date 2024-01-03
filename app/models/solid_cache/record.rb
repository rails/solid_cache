# frozen_string_literal: true

module SolidCache
  class Record < ActiveRecord::Base
    NULL_INSTRUMENTER = ActiveSupport::Notifications::Instrumenter.new(ActiveSupport::Notifications::Fanout.new)

    self.abstract_class = true

    connects_to(**SolidCache.connects_to) if SolidCache.connects_to

    class << self
      def disable_instrumentation(&block)
        connection.with_instrumenter(NULL_INSTRUMENTER, &block)
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
