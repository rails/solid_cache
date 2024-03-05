class RemoveKeyIndexFromSolidCacheEntries < ActiveRecord::Migration[7.0]
  def change
    change_table :solid_cache_entries do |t|
      t.remove_index :key, unique: true
    end
  end
end
