Rails.application.routes.draw do
  mount ActiveSupport::DatabaseCache::Engine => "/active_support-database_cache"
end
