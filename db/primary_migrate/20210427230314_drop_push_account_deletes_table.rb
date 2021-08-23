class DropPushAccountDeletesTable < ActiveRecord::Migration[6.1]
  def change
    drop_table :push_account_deletes do |t|
      t.datetime :created_at, null: false
      t.integer  :agency_id, null: false
      t.string   :uuid, null: false

      t.index :name, name: :index_push_account_deletes_on_created_at
    end
  end
end
