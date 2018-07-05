class CreatePasswordMetrics < ActiveRecord::Migration[5.1]
  def change
    create_table :password_metrics do |t|
      t.integer :metric, null: false
      t.float :value, null: false
      t.integer :count, null: false
      t.index :metric
      t.index :value
      t.index [:metric, :value], unique: true
    end
  end
end
