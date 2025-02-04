# frozen_string_literal: true

module SolidCache
  class Record < ActiveRecord::Base
    NULL_INSTRUMENTER = ActiveSupport::Notifications::Instrumenter.new(ActiveSupport::Notifications::Fanout.new)

    self.abstract_class = true

    connects_to(**SolidCache.configuration.connects_to) if SolidCache.configuration.connects_to

    class << self
      def disable_instrumentation(&block)
        with_instrumenter(NULL_INSTRUMENTER, &block)
      end

      def with_instrumenter(instrumenter, &block)
        if connection.respond_to?(:with_instrumenter)
          connection.with_instrumenter(instrumenter, &block)
        else
          begin
            old_instrumenter, ActiveSupport::IsolatedExecutionState[:active_record_instrumenter] = ActiveSupport::IsolatedExecutionState[:active_record_instrumenter], instrumenter
            block.call
          ensure
            ActiveSupport::IsolatedExecutionState[:active_record_instrumenter] = old_instrumenter
          end
        end
      end

      def with_shard(shard, &block)
        if shard && SolidCache.configuration.sharded?
          connected_to(shard: shard, role: default_role, prevent_writes: false, &block)
        else
          block.call
        end
      end

      def each_shard(&block)
        return to_enum(:each_shard) unless block_given?

        if SolidCache.configuration.sharded?
          SolidCache.configuration.shard_keys.each do |shard|
            Record.with_shard(shard, &block)
          end
        else
          yield
        end
      end
    end
  end
end

ActiveSupport.run_load_hooks :solid_cache, SolidCache::Record
