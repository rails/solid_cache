class CreateActiveSupportDatabaseCacheEntries < ActiveRecord::Migration[7.0]
  def change
    create_table :active_support_database_cache_entries do |t|
      t.string   :key,       null: false
      t.binary   :value,     null: false
      t.datetime :expires_at
      t.index    :key,       unique: true
      t.index    :expires_at
    end
  end
end
