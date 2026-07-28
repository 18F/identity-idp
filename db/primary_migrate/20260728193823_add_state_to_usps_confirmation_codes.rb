class AddStateToUspsConfirmationCodes < ActiveRecord::Migration[8.0]
  def change
    add_column :usps_confirmation_codes, :state, :string, comment: 'sensitive=false'
  end
end
