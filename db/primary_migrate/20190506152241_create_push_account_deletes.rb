class CreatePushAccountDeletes < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  def change
    create_table :push_account_deletes do |t|
      t.datetime :created_at, null: false
      t.integer  :agency_id, null: false
      t.string   :uuid, null: false
    end
    add_index :push_account_deletes, %i[created_at], algorithm: :concurrently
  end
end
