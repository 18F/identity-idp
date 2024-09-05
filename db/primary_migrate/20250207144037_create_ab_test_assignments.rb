class CreateAbTestAssignments < ActiveRecord::Migration[8.0]
  def change
    create_table :ab_test_assignments do |t|
      t.string :experiment, null: false
      t.string :discriminator, null: false
      t.string :bucket, null: false
      t.index [:experiment, :discriminator], unique: true
    end
  end
end
