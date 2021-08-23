class CreateMonthlySpAuthCounts < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  def change
    create_table :monthly_sp_auth_counts do |t|
      t.string :issuer, null: false
      t.integer :ial, null: false, limit: 1
      t.string :year_month, null: false
      t.integer :user_id, null: false
      t.integer :auth_count, default: 1, null: false
    end
    add_index :monthly_sp_auth_counts, %i[issuer ial year_month user_id],
              unique: true, name: "index_monthly_sp_auth_counts_on_issuer_ial_month_user_id"
  end
end
