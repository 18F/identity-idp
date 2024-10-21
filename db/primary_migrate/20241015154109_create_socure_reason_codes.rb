class CreateSocureReasonCodes < ActiveRecord::Migration[7.1]
  def change
    create_table :socure_reason_codes do |t|
      t.string :code, comment: 'sensitive=false'
      t.string :group, comment: 'sensitive=false'
      t.text :description, comment: 'sensitive=false'
      t.datetime :added_at, comment: 'sensitive=false'
      t.datetime :deactivated_at, comment: 'sensitive=false'

      t.timestamps comment: 'sensitive=false'

      t.index :code, unique: true
      t.index :deactivated_at
    end
  end
end
