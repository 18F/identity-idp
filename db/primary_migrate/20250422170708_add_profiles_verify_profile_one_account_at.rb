class AddProfilesVerifyProfileOneAccountAt < ActiveRecord::Migration[8.0]
  def change
    add_column :profiles, :verify_profile_one_account_at, :datetime
  end
end
