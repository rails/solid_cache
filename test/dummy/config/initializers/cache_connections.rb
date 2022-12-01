ActiveSupport.on_load(:active_storage_database_cache) do
  connects_to database: { writing: :primary, reading: :primary_replica }
end
