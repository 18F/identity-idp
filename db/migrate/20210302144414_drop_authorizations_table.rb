class DropAuthorizationsTable < ActiveRecord::Migration[6.1]
  def change
    drop_table :authorizations do |t|
      t.string   :provider
      t.string   :uid
      t.bigint  :user_id
      t.datetime :authorized_at
      t.timestamps

      t.index [:provider, :uid]
      t.index [:user_id]
    end
  end
end
