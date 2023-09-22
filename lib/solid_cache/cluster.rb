
module SolidCache
  class Cluster
    include Instrumented, Sharded, Execution, Trimming, Stats

    def initialize(options = {})
      super(options)
    end

    def setup!
      setup_shards!
    end
  end
end
