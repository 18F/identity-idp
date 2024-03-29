class DropMonthlyAuthCounts < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    drop_table :monthly_auth_counts
  end

  def down
    create_table :monthly_auth_counts do |t|
      t.string :issuer, null: false
      t.string :year_month, null: false
      t.integer :user_id, null: false
      t.integer :auth_count, default: 1, null: false
    end
    add_index :monthly_auth_counts, %i[issuer year_month user_id], algorithm: :concurrently, unique: true
  end
end
