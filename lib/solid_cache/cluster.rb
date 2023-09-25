
module SolidCache
  class Cluster
    include Instrumented, Connections, Execution, Trimming, Stats

    def initialize(options = {})
      super(options)
    end

    def setup!
      super
    end
  end
end
