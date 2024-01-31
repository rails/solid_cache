# frozen_string_literal: true

require "zeitwerk"
require "solid_cache/engine"

loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/active_support")
loader.ignore("#{__dir__}/generators")
loader.setup

module SolidCache
  mattr_reader :configuration, default: Configuration.new

  class << self
    # delegate :executor, :executor=, to: :configuration
    # delegate :connects_to, :connects_to=, to: :configuration
    # delegate :key_hash_stage, :key_hash_stage=, to: :configuration
    # delegate :store_options, :store_options=, to: :configuration
  end
end

loader.eager_load
