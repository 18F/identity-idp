class DocAuthLog < ApplicationRecord
  belongs_to :user

  def self.verified_users_count
    Profile.where.not(verified_at: nil).count
  end
end
