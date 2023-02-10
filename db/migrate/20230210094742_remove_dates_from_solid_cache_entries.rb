class RemoveDatesFromSolidCacheEntries < ActiveRecord::Migration[7.0]
  def change
    remove_index :solid_cache_entries, :expires_at
    remove_index :solid_cache_entries, :updated_at
    remove_column :solid_cache_entries, :expires_at, :datetime
    remove_column :solid_cache_entries, :updated_at, :datetime
  end
end
