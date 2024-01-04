# frozen_string_literal: true

Rails.application.routes.draw do
  mount SolidCache::Engine => "/solid_cache"
end
