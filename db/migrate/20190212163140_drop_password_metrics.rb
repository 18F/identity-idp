class DropPasswordMetrics < ActiveRecord::Migration[5.1]
  def up
    drop_table :password_metrics
  end

  # :reek:TooManyStatements :reek:UncommunicativeVariableName :reek:FeatureEnvy
  def down
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
