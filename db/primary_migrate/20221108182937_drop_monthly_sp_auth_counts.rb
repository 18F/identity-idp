class DropMonthlySpAuthCounts < ActiveRecord::Migration[7.0]
  def change
    drop_table :monthly_sp_auth_counts do |t|
      t.string "issuer", null: false
      t.integer "ial", limit: 2, null: false
      t.string "year_month", null: false
      t.integer "user_id", null: false
      t.integer "auth_count", default: 1, null: false
      t.index ["issuer", "ial", "year_month", "user_id"], name: "index_monthly_sp_auth_counts_on_issuer_ial_month_user_id", unique: true
    end
  end
end
