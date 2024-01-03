# frozen_string_literal: true

module SolidCache
  class Cluster
    include Connections, Execution, Expiry, Stats

    def initialize(options = {})
      super(options)
    end

    def setup!
      super
    end
  end
end
