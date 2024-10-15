class CreateSocureReasonCodes < ActiveRecord::Migration[7.1]
  def change
    create_table :socure_reason_codes do |t|
      t.string :code
      t.text :description
      t.datetime :added_at
      t.datetime :deactivated_at

      t.timestamps

      t.index :code, unique: true
    end
  end
end
