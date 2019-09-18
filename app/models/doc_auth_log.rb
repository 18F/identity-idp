class DocAuthLog < ApplicationRecord
  belongs_to :user

  def self.verified_users_count
    DocAuthLog.where.not(verified_view_at: nil).count
  end
end
