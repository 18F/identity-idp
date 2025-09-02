class RenameDuplicateProfileToDuplicateProfileSet < ActiveRecord::Migration[8.0]
  def change
    safety_assured { rename_table :duplicate_profiles, :duplicate_profile_sets }
  end
end
