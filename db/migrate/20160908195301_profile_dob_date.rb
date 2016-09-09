class ProfileDobDate < ActiveRecord::Migration
  def up
    change_column :profiles, :dob, 'date USING CAST(dob AS date)'
  end

  def down
    change_column :profiles, :dob, :string
  end
end
