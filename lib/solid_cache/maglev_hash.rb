# frozen_string_literal: true

# See https://static.googleusercontent.com/media/research.google.com/en//pubs/archive/44824.pdf

module SolidCache
  class MaglevHash
    attr_reader :nodes

    # Must be prime
    TABLE_SIZE = 2053

    def initialize(nodes)
      raise ArgumentError, "No nodes specified" if nodes.count == 0
      raise ArgumentError, "Maximum node count is #{TABLE_SIZE}" if nodes.count > TABLE_SIZE

      @nodes = nodes.uniq.sort
      @lookup = build_lookup
    end

    def node(key)
      nodes[lookup[quick_hash(key) % TABLE_SIZE]]
    end

    private
      attr_reader :lookup, :node_count

      def build_lookup
        lookup = Array.new(TABLE_SIZE, nil)

        node_preferences = nodes.map { |node| build_preferences(node) }
        node_count = nodes.count

        TABLE_SIZE.times do |i|
          node_index = i % node_count
          preferences = node_preferences[node_index]
          slot = preferences.preferred_free_slot(lookup)
          lookup[slot] = node_index
        end

        lookup
      end

      def build_preferences(node)
        offset = md5(node, :offset) % TABLE_SIZE
        skip = md5(node, :skip) % (TABLE_SIZE - 1) + 1

        Preferences.new(offset, skip)
      end

      def md5(*args)
        ::Digest::MD5.digest(args.join).unpack1("L>")
      end

      def quick_hash(key)
        Zlib.crc32(key.to_s)
      end

      class Preferences
        def initialize(offset, skip)
          @preferred_slots = TABLE_SIZE.times.map { |i| (offset + i * skip) % TABLE_SIZE }
          @rank = 0
        end

        def preferred_free_slot(lookup)
          loop do
            slot = next_slot
            return slot if lookup[slot].nil?
          end
        end

        private
          attr_reader :rank, :preferred_slots

          def next_slot
            preferred_slots[rank].tap { @rank += 1 }
          end
      end
  end
end
