module SolidCache
  module AsyncExecution
    def initialize(options)
      super(options)
      @executor = Concurrent::SingleThreadExecutor.new(max_queue: 100, fallback_policy: :discard)
    end

    private
      def async(&block)
        # Need current shard right now, not when block is called
        current_shard = Entry.current_shard
        @executor << ->() { block.call(current_shard) }
      end
  end
end
