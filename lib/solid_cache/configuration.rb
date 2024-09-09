# frozen_string_literal: true

module SolidCache
  class Configuration
    attr_reader :store_options, :connects_to, :executor, :size_estimate_samples, :encrypt, :encryption_context_properties

    def initialize(store_options: {}, database: nil, databases: nil, connects_to: nil, executor: nil, encrypt: false, encryption_context_properties: nil, size_estimate_samples: 10_000)
      @store_options = store_options
      @size_estimate_samples = size_estimate_samples
      @executor = executor
      @encrypt = encrypt
      @encryption_context_properties = encryption_context_properties
      @encryption_context_properties ||= default_encryption_context_properties if encrypt?
      set_connects_to(database: database, databases: databases, connects_to: connects_to)
    end

    def sharded?
      connects_to && connects_to[:shards]
    end

    def shard_keys
      sharded? ? connects_to[:shards].keys : []
    end

    def encrypt?
      encrypt.present?
    end

    private
      def set_connects_to(database:, databases:, connects_to:)
        if [database, databases, connects_to].compact.size > 1
          raise ArgumentError, "You can only specify one of :database, :databases, or :connects_to"
        end

        @connects_to =
          case
          when database
            { shards: { database.to_sym => { writing: database.to_sym } } }
          when databases
            { shards: databases.map(&:to_sym).index_with { |database| { writing: database } } }
          when connects_to
            connects_to
          else
            nil
          end
      end

      def default_encryption_context_properties
        require "active_record/encryption/message_pack_message_serializer"

        {
          # No need to compress, the cache does that already
          encryptor: ActiveRecord::Encryption::Encryptor.new(compress: false),
          # Binary column only serializer that is 40% more efficient than the default MessageSerializer
          message_serializer: ActiveRecord::Encryption::MessagePackMessageSerializer.new
        }
      end
  end
end
