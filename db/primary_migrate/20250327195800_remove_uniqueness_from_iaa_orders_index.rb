class RemoveUniquenessFromIaaOrdersIndex < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    remove_index :iaa_orders, name: "index_iaa_orders_on_iaa_gtc_id_and_order_number"
    add_index :iaa_orders, [:iaa_gtc_id, :order_number], algorithm: :concurrently
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "Cannot reverse migration that removed uniqueness from index"
  end
end
