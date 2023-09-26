
module SolidCache
  class Cluster
    include Connections, Execution, Expiry, Instrumented, Stats

    def initialize(options = {})
      super(options)
    end

    def setup!
      super
    end
  end
end
