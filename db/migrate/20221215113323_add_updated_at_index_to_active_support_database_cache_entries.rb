class AddUpdatedAtIndexToActiveSupportDatabaseCacheEntries < ActiveRecord::Migration[7.0]
  def change
    add_index :active_support_database_cache_entries, :updated_at
  end
end
