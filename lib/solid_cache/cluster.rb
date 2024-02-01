# frozen_string_literal: true

module SolidCache
  class Cluster
    include Connections, Execution, Expiry, Stats

    attr_reader :error_handler

    def initialize(options = {})
      @error_handler = options[:error_handler]
      super(options)
    end

    def setup!
      super
    end
  end
end
