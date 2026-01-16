class CreateAbTestAssignments < ActiveRecord::Migration[8.0]
  def change
    create_table :ab_test_assignments do |t|
      t.string :experiment, null: false, comment: 'sensitive=false'
      t.string :discriminator, null: false, comment: 'sensitive=false'
      t.string :bucket, null: false, comment: 'sensitive=false'
      t.index [:experiment, :discriminator], unique: true, using: :btree
    end
  end
end
