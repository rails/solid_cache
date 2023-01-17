class CreateSolidCacheEntries < ActiveRecord::Migration[7.0]
  def change
    create_table :solid_cache_entries do |t|
      t.binary   :key,       null: false,   limit: 1024
      t.binary   :value,     null: false,   limit: 512.megabytes
      t.datetime :expires_at
      t.timestamps           null: false

      t.index    :key,       unique: true
      t.index    :expires_at
      t.index    :updated_at
    end
  end
end
