
module SolidCache
  class Cluster
    require "solid_cache/cluster/hash_ring"
    require "solid_cache/cluster/connection_handling"
    require "solid_cache/cluster/async_execution"
    require "solid_cache/cluster/trimming"
    require "solid_cache/cluster/stats"

    include ConnectionHandling, AsyncExecution
    include Trimming
    include Stats

    def initialize(options = {})
      super(options)
    end
  end
end
