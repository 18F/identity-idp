class DropBouncedAtColumnFromUspsConfirmationCode < ActiveRecord::Migration[7.1]
  def change
    safety_assured do
      remove_column :usps_confirmation_codes, :bounced_at, :datetime, precision: nil
    end
  end
end
