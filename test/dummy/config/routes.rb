Rails.application.routes.draw do
  mount SolidCache::Engine => "/solid_cache"
end
