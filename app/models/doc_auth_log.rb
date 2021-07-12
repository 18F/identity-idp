class DocAuthLog < ApplicationRecord
  self.ignored_columns = %w[no_sp_campaign]
  belongs_to :user

  def self.verified_users_count
    Profile.where.not(verified_at: nil).count
  end
end
