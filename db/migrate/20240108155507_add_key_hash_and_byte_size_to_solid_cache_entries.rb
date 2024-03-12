class AddKeyHashAndByteSizeToSolidCacheEntries < ActiveRecord::Migration[7.0]
  def change
    change_table :solid_cache_entries do |t|
      t.column :key_hash,  :integer, null: true, limit: 8
      t.column :byte_size, :integer, null: true, limit: 4
    end
  end
end
