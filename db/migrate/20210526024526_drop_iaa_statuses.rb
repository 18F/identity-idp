class DropIaaStatuses < ActiveRecord::Migration[6.1]
  def change
    safety_assured do
      remove_reference :iaa_gtcs, :iaa_status, foreign_key: true
      remove_reference :iaa_orders, :iaa_status, foreign_key: true
    end

    reversible do |dir|
      dir.up do
        drop_table :iaa_statuses
      end

      dir.down do
        create_table :iaa_statuses do |t|
          t.string :name, null: false
          t.integer :order, null: false
          t.string :partner_name

          t.index :name, unique: true
          t.index :order, unique: true
        end
      end
    end
  end
end
