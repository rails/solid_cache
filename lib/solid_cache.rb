# frozen_string_literal: true

require "zeitwerk"
require "solid_cache/engine"

loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/active_support")
loader.ignore("#{__dir__}/generators")
loader.setup

module SolidCache
  mattr_accessor :executor
  mattr_accessor :configuration, default: Configuration.new

  ActiveSupport.run_load_hooks(:solid_cache, self)
end

loader.eager_load
