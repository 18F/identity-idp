class RecoveryCode < ApplicationRecord
  belongs_to :user

  #     create_table :recovery_codes do |t|
  #       t.integer :user_id, null: false
  #       t.text :code, null: false
  #       t.integer :used, default: 0, null: false
  #       t.timestamps
  #     end
  #
end
