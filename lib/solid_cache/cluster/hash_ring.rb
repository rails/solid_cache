# Taken from the redis-rb gem (https://github.com/redis/redis-rb)

# Copyright (c) 2009 Ezra Zygmuntowicz

# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:

# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# frozen_string_literal: true
require 'zlib'
require 'digest/md5'

module SolidCache
  class Cluster
    class HashRing
      POINTS_PER_SERVER = 160 # this is the default in libmemcached

      attr_reader :ring, :sorted_keys, :replicas, :nodes

      # nodes is a list of objects that have a proper to_s representation.
      # replicas indicates how many virtual points should be used pr. node,
      # replicas are required to improve the distribution.
      def initialize(nodes = [], replicas = POINTS_PER_SERVER)
        @replicas = replicas
        @ring = {}
        @nodes = []
        @sorted_keys = []
        nodes.each do |node|
          add_node(node)
        end
      end

      # Adds a `node` to the hash ring (including a number of replicas).
      def add_node(node)
        @nodes << node
        @replicas.times do |i|
          key = server_hash_for("#{node}:#{i}")
          @ring[key] = node
          @sorted_keys << key
        end
        @sorted_keys.sort!
      end

      def remove_node(node)
        @nodes.reject! { |n| n.id == node }
        @replicas.times do |i|
          key = server_hash_for("#{node}:#{i}")
          @ring.delete(key)
          @sorted_keys.reject! { |k| k == key }
        end
      end

      # get the node in the hash ring for this key
      def get_node(key)
        hash = hash_for(key)
        idx = binary_search(@sorted_keys, hash)
        @ring[@sorted_keys[idx]]
      end

      def iter_nodes(key)
        return [nil, nil] if @ring.empty?

        crc = hash_for(key)
        pos = binary_search(@sorted_keys, crc)
        @ring.size.times do |n|
          yield @ring[@sorted_keys[(pos + n) % @ring.size]]
        end
      end

      private

      def hash_for(key)
        Zlib.crc32(key)
      end

      def server_hash_for(key)
        ::Digest::MD5.digest(key).unpack1("L>")
      end

      # Find the closest index in HashRing with value <= the given value
      def binary_search(ary, value)
        upper = ary.size
        lower = 0

        while lower < upper
          mid = (lower + upper) / 2
          if ary[mid] > value
            upper = mid
          else
            lower = mid + 1
          end
        end

        upper - 1
      end
    end
  end
end
