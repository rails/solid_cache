# frozen_string_literal: true

module SolidCache
  class Store
    module Stats
      def initialize(options = {})
        super(options)
      end

      def stats
        {
          connections: connections.count,
          connection_stats: connections_stats
        }
      end

      private
        def connections_stats
          with_each_connection.to_h { |connection| [ Entry.current_shard, connection_stats ] }
        end

        def connection_stats
          oldest_created_at = Entry.order(:id).pick(:created_at)

          {
            max_age: max_age,
            oldest_age: oldest_created_at ? Time.now - oldest_created_at : nil,
            max_entries: max_entries,
            entries: Entry.id_range
          }
        end
    end
  end
end
