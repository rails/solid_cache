# See https://static.googleusercontent.com/media/research.google.com/en//pubs/archive/44824.pdf

module SolidCache
  class MaglevHash
    attr_reader :nodes

    # Must be prime
    TABLE_SIZE = 2053

    def initialize(nodes)
      @nodes = nodes.uniq.sort
      @node_count = nodes.count

      raise ArgumentError, "No nodes specified" if nodes.count == 0
      raise ArgumentError, "Maximum node count is #{TABLE_SIZE}" if nodes.count > TABLE_SIZE

      @lookup = Array.new(TABLE_SIZE, nil)
      popuplate_lookup
    end

    def node(key)
      nodes[lookup[quick_hash(key) % TABLE_SIZE]]
    end

    private
      attr_reader :lookup, :node_count

      def popuplate_lookup
        node_preferences = nodes.map { |node| build_preferences(node) }

        TABLE_SIZE.times do |i|
          node_index = i % node_count
          preferences = node_preferences[node_index]
          slot = preferred_free_slot(preferences)
          lookup[slot] = node_index
        end
      end

      def build_preferences(node)
        offset = md5(node, :offset) % TABLE_SIZE
        skip = md5(node, :skip) % (TABLE_SIZE - 1) + 1

        Preferences.new TABLE_SIZE.times.map { |i| (offset + i * skip) % TABLE_SIZE }
      end

      def preferred_free_slot(preferences)
        loop do
          slot = preferences.next
          return slot if slot_free?(slot)
        end
      end

      def slot_free?(slot)
        lookup[slot].nil?
      end

      def md5(*args)
        ::Digest::MD5.digest(args.join).unpack1("L>")
      end

      def quick_hash(key)
        Zlib.crc32(key.to_s)
      end

      class Preferences
        def initialize(preferences)
          @preferences = preferences
          @rank = 0
        end

        def next
          preferences[rank].tap { @rank += 1 }
        end

        private
          attr_reader :rank, :preferences
      end
  end
end
