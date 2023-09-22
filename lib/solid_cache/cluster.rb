
module SolidCache
  class Cluster
    require "solid_cache/maglev_hash"
    require "solid_cache/shards"
    require "solid_cache/cluster/instrumented"
    require "solid_cache/cluster/execution"
    require "solid_cache/cluster/trimming"
    require "solid_cache/cluster/sharded"
    require "solid_cache/cluster/stats"

    include Instrumented, Sharded, Execution, Trimming, Stats

    def initialize(options = {})
      super(options)
    end

    def setup!
      setup_shards!
    end
  end
end
