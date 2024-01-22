# frozen_string_literal: true

module SolidCache
  class Configuration
    attr_reader :store_options, :connects_to, :executor, :size_estimate_samples

    def initialize(store_options: {}, database: nil, databases: nil, connects_to: nil, executor: nil, size_estimate_samples: 10_000)
      @store_options = store_options
      @size_estimate_samples = size_estimate_samples
      @executor = executor
      set_connects_to(database: database, databases: databases, connects_to: connects_to)
    end

    def sharded?
      connects_to && connects_to[:shards]
    end

    def shard_keys
      sharded? ? connects_to[:shards].keys : []
    end

    private
      def set_connects_to(database:, databases:, connects_to:)
        if [database, databases, connects_to].compact.size > 1
          raise ArgumentError, "You can only specify one of :database, :databases, or :connects_to"
        end

        @connects_to =
          case
          when database
            { database: { writing: database.to_sym } }
          when databases
            { shards: databases.map(&:to_sym).index_with { |database| { writing: database } } }
          when connects_to
            connects_to
          else
            nil
          end
      end
  end
end
