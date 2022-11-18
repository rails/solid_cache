class CreateActiveSupportDatabaseCacheEntries < ActiveRecord::Migration[7.0]
  def change
    collation = case ActiveRecord::Base.connection.adapter_name
                when "Mysql2"
                  "utf8mb4_bin"
                end

    create_table :active_support_database_cache_entries do |t|
      t.string   :key,       null: false, collation: collation
      t.binary   :value,     null: false
      t.datetime :expires_at
      t.timestamps           null: false

      t.index    :key,       unique: true
      t.index    :expires_at
    end
  end
end
